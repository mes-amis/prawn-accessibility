# frozen_string_literal: true

require_relative 'marked_content'

module Prawn
  module Accessibility
    # Manages the PDF structure tree for tagged/accessible PDFs.
    #
    # The structure tree provides the logical structure of a document,
    # mapping marked content sequences in page content streams to
    # structure elements (headings, paragraphs, tables, etc.).
    #
    # It talks to the document exclusively through the *public* renderer API
    # (`ref!`, `deref`, `add_content`, `state`), so it requires no patches to
    # any pdf-core class.
    #
    # PDF spec references: Section 14.7 (Logical Structure)
    #
    # @api private
    class StructureTree
      include MarkedContent

      # @return [PDF::Core::Renderer] owning renderer
      attr_reader :renderer

      # @return [PDF::Core::Reference] StructTreeRoot indirect object
      attr_reader :root_ref

      # @return [PDF::Core::Reference] Document-level structure element
      attr_reader :document_elem_ref

      # @return [Array<Hash>] all structure elements created
      attr_reader :elements

      # @return [Hash{Integer => Array}] page StructParents index => array of
      #   structure element refs for marked content on that page
      attr_reader :parent_tree_map

      # @return [Integer] next available MCID for the current page
      attr_reader :next_mcid

      # @return [Array<PDF::Core::Reference>] stack of open structure elements
      attr_reader :element_stack

      # @param renderer [PDF::Core::Renderer]
      def initialize(renderer)
        @renderer = renderer
        @elements = []
        @parent_tree_map = {}
        @next_mcid = 0
        @element_stack = []
        @page_mcid_map = {} # page_ref_id => next mcid for that page
        @open_sequences = [] # marked-content sequences not yet closed
        @root_ref = nil
        @document_elem_ref = nil
      end

      # Allocate the next MCID for the current page and track it.
      #
      # @return [Integer] the allocated MCID
      def allocate_mcid
        page = renderer.state.page
        page_id = page.dictionary.identifier

        @page_mcid_map[page_id] ||= 0
        mcid = @page_mcid_map[page_id]
        @page_mcid_map[page_id] += 1

        mcid
      end

      # Add a structure element as a child of the current open element
      # (or the document element if none is open).
      #
      # @param tag [Symbol] structure type (e.g., :P, :H1, :Table, :TD)
      # @param attributes [Hash] additional attributes for the structure element
      # @option attributes [String] :Alt alternative text (for Figure, Formula)
      # @option attributes [String] :ActualText replacement text for screen
      #   readers (e.g., "required" instead of reading "*")
      # @option attributes [String] :Lang language tag
      # @option attributes [Symbol] :Scope TH scope (:Column, :Row, :Both)
      # @return [PDF::Core::Reference] the structure element reference
      def add_element(tag, attributes = {})
        parent_ref = current_element || document_element

        elem_data = {
          Type: :StructElem,
          S: tag,
          P: parent_ref,
          K: [],
        }

        elem_data[:Alt] = attributes[:Alt] if attributes[:Alt]
        elem_data[:ActualText] = attributes[:ActualText] if attributes[:ActualText]
        elem_data[:Lang] = attributes[:Lang] if attributes[:Lang]

        if attributes[:Scope]
          elem_data[:A] = {
            O: :Table,
            Scope: attributes[:Scope],
          }
        end

        elem_ref = renderer.ref!(elem_data)
        @elements << elem_ref

        # Add as child of parent
        parent_data = renderer.deref(parent_ref)
        parent_data[:K] << elem_ref

        elem_ref
      end

      # Begin a structure element scope. Content rendered inside will be
      # children of this element.
      #
      # @param tag [Symbol] structure type
      # @param attributes [Hash] additional attributes
      # @return [PDF::Core::Reference] the opened structure element
      def begin_element(tag, attributes = {})
        elem_ref = add_element(tag, attributes)
        @element_stack.push(elem_ref)
        elem_ref
      end

      # End the current structure element scope.
      #
      # @return [PDF::Core::Reference] the closed structure element
      def end_element
        @element_stack.pop
      end

      # Add marked content to the current structure element.
      # This allocates an MCID, records the mapping, and emits BDC/EMC
      # operators around the yielded block.
      #
      # If the block changes page (see {#across_page_change}), the sequence is
      # closed on the old page and reopened on the new one with a fresh MCID
      # that refers to the same structure element.
      #
      # @param tag [Symbol] marked content tag (e.g., :P, :Span)
      # @param struct_elem_ref [PDF::Core::Reference, nil] the structure element
      #   this content belongs to. If nil, uses current_element.
      # @yield content to render inside the marked content sequence
      # @return [void]
      def mark_content(tag, struct_elem_ref: nil, &block)
        elem_ref = struct_elem_ref || current_element || document_element
        with_open_sequence({ tag: tag, elem: elem_ref }, &block)
      end

      # Mark content as an artifact (decorative, not read by screen readers).
      #
      # Like {#mark_content}, the artifact is closed and reopened if the block
      # changes page.
      #
      # @param artifact_type [Symbol, nil] optional artifact type
      #   (:Pagination, :Layout, :Page, :Background)
      # @yield content to render as artifact
      # @return [void]
      def mark_artifact(artifact_type: nil, &block)
        with_open_sequence({ artifact: true, type: artifact_type }, &block)
      end

      # Keep open marked-content sequences balanced across a page change.
      #
      # A marked-content sequence must begin and end in the same content
      # stream. Every open sequence is closed (innermost first) on the current
      # page, the block is yielded to change page, and the sequences are
      # reopened (outermost first) on the new current page. Reopened tagged
      # sequences get a new MCID referencing the same structure element.
      #
      # @yield the page change
      # @return [Object] the block's result
      def across_page_change
        return yield if @open_sequences.empty?

        @open_sequences.size.times { end_marked_content }
        result = yield
        @open_sequences.each { |sequence| begin_sequence(sequence) }
        result
      end

      # Finalize the structure tree before rendering. Called via
      # before_render callback.
      #
      # Builds the StructTreeRoot, ParentTree, and wires everything
      # into the Catalog.
      #
      # @return [void]
      def finalize!
        return if @elements.empty? && @parent_tree_map.empty?

        build_root
        build_parent_tree
        assign_struct_parents_to_pages
        attach_to_catalog
      end

      private

      # Open a sequence, yield, and close it, tracking it while it is open so
      # {#across_page_change} can carry it onto a new page.
      #
      # @param sequence [Hash] see {#begin_sequence}
      # @return [void]
      def with_open_sequence(sequence)
        begin_sequence(sequence)
        @open_sequences.push(sequence)
        yield if block_given?
        @open_sequences.pop
        end_marked_content
      end

      # Emit the opening operator for a sequence on the current page.
      #
      # A tagged sequence (<tt>{ tag:, elem: }</tt>) allocates an MCID on the
      # current page, records it in the ParentTree map, and adds a marked
      # content reference to the element's K array. An artifact sequence
      # (<tt>{ artifact: true, type: }</tt>) emits /Artifact BMC, or BDC with
      # a /Type when one is given.
      #
      # @param sequence [Hash]
      # @return [void]
      def begin_sequence(sequence)
        return begin_artifact(sequence[:type]) if sequence[:artifact]

        elem_ref = sequence[:elem]
        mcid = allocate_mcid
        page_ref = renderer.state.page.dictionary

        # Record which element owns this MCID on this page, and reference the
        # marked content from the element's K array.
        (@parent_tree_map[page_struct_parents_index(page_ref)] ||= [])[mcid] = elem_ref
        renderer.deref(elem_ref)[:K] << { Type: :MCR, MCID: mcid, Pg: page_ref }

        begin_marked_content_with_properties(sequence[:tag], { MCID: mcid })
      end

      # @param artifact_type [Symbol, nil]
      # @return [void]
      def begin_artifact(artifact_type)
        if artifact_type
          begin_marked_content_with_properties(:Artifact, { Type: artifact_type })
        else
          begin_marked_content(:Artifact)
        end
      end

      # Forward content emission (used by the MarkedContent mixin) to the
      # renderer's public API.
      #
      # @param str [String]
      # @return [void]
      def add_content(str)
        renderer.add_content(str)
      end

      # The current open structure element, or nil if none.
      #
      # @return [PDF::Core::Reference, nil]
      def current_element
        @element_stack.last
      end

      # Get or create the Document-level structure element.
      #
      # @return [PDF::Core::Reference]
      def document_element
        return @document_elem_ref if @document_elem_ref

        @document_elem_ref = renderer.ref!(
          Type: :StructElem,
          S: :Document,
          P: nil, # will be set to StructTreeRoot in finalize!
          K: [],
        )
        @elements << @document_elem_ref
        @document_elem_ref
      end

      # Get or assign a StructParents index for a page.
      #
      # @param page_ref [PDF::Core::Reference] page dictionary reference
      # @return [Integer] the StructParents index
      def page_struct_parents_index(page_ref)
        page_ref.data[:StructParents] ||= @parent_tree_map.size
        page_ref.data[:StructParents]
      end

      # Build the StructTreeRoot object.
      #
      # @return [void]
      def build_root
        @root_ref = renderer.ref!(
          Type: :StructTreeRoot,
          K: document_element,
          ParentTree: nil, # set in build_parent_tree
        )

        # Point Document element's parent to the root
        doc_data = renderer.deref(@document_elem_ref)
        doc_data[:P] = @root_ref
      end

      # Build the ParentTree (a number tree mapping StructParents indices
      # to arrays of structure element references).
      #
      # @return [void]
      def build_parent_tree
        # ParentTree is a number tree. For simplicity, use a flat Nums array
        # since most documents won't have enough pages to need a balanced tree.
        nums = []
        @parent_tree_map.sort_by { |k, _| k }.each do |index, elem_array|
          nums << index
          nums << renderer.ref!(elem_array)
        end

        parent_tree_ref = renderer.ref!(Type: :ParentTree, Nums: nums)
        root_data = renderer.deref(@root_ref)
        root_data[:ParentTree] = parent_tree_ref
      end

      # Ensure each page that has marked content has a StructParents entry.
      # (Already handled lazily in page_struct_parents_index, but verify.)
      #
      # @return [void]
      def assign_struct_parents_to_pages
        # Already assigned lazily when mark_content is called.
        # This method exists as a hook for any additional finalization.
      end

      # Wire the StructTreeRoot into the document Catalog.
      #
      # @return [void]
      def attach_to_catalog
        renderer.state.store.root.data[:StructTreeRoot] = @root_ref
      end
    end
  end
end
