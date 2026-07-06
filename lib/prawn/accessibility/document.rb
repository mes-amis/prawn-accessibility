# frozen_string_literal: true

require 'prawn'
require_relative 'structure_tree'

module Prawn
  module Accessibility
    # Instance methods included into {Prawn::Document} to provide the
    # high-level tagged-PDF (accessibility) API.
    #
    # Tagging is opt-in: create the document with <tt>marked: true</tt> (see the
    # initializer shim at the bottom of this file). Everything here is built on
    # Prawn/pdf-core's *public* API (`renderer`, `state`, `min_version`,
    # `before_render`); no core class is patched to support it.
    #
    # @example
    #   pdf = Prawn::Document.new(marked: true, language: 'en-US')
    #   pdf.structure(:H1) { pdf.text 'Document Title' }
    #   pdf.structure(:P)  { pdf.text 'Body paragraph text.' }
    #   pdf.artifact       { pdf.text 'Page 1' } # not read by screen readers
    module DocumentExtensions
      # The structure tree for this document, or nil if not tagged.
      #
      # @return [Prawn::Accessibility::StructureTree, nil]
      def structure_tree
        @accessibility_structure_tree
      end

      # Whether this document is tagged for accessibility.
      #
      # @return [Boolean]
      def tagged?
        !@accessibility_structure_tree.nil?
      end

      # Wrap content in a structure element. The block's content will be
      # associated with the given tag in the document's structure tree.
      #
      # Can be nested — inner structure calls become children of the outer.
      #
      # @param tag [Symbol] PDF structure type (:Document, :Part, :Sect,
      #   :H1-:H6, :P, :L, :LI, :Lbl, :LBody, :Table, :TR, :TH, :TD,
      #   :Figure, :Formula, :Form, :Span, :Link, :Note, :BlockQuote,
      #   :Caption, :TOC, :TOCI, :Reference)
      # @param attributes [Hash] optional attributes
      # @option attributes [String] :Alt alternative text (for Figure, Formula)
      # @option attributes [String] :ActualText replacement text for screen
      #   readers (e.g., "required" for "*", "selected" for "X")
      # @option attributes [String] :Lang language override for this element
      # @option attributes [Symbol] :Scope table header scope (:Column, :Row, :Both)
      # @yield content to render inside this structure element
      # @return [void]
      def structure(tag, attributes = {}, &block)
        return yield if !tagged? || !block

        tree = structure_tree
        tree.begin_element(tag, attributes)
        tree.mark_content(tag, &block)
        tree.end_element
      end

      # Wrap content in a structure element without marking the content
      # directly. Use this for container elements (Table, TR, L, LI) where
      # the children will each have their own marked content.
      #
      # @param tag [Symbol] PDF structure type
      # @param attributes [Hash] optional attributes
      # @yield content to render inside this structure element
      # @return [void]
      def structure_container(tag, attributes = {}, &block)
        return yield if !tagged? || !block

        tree = structure_tree
        tree.begin_element(tag, attributes)
        yield
        tree.end_element
      end

      # Mark content as an artifact (decorative, not read by screen readers).
      # Use for page numbers, decorative borders, backgrounds, watermarks.
      #
      # @param type [Symbol, nil] artifact type (:Pagination, :Layout,
      #   :Page, :Background)
      # @yield content to render as artifact
      # @return [void]
      def artifact(type: nil, &block)
        return yield if !tagged? || !block

        structure_tree.mark_artifact(artifact_type: type, &block)
      end

      # Render a heading at the specified level.
      #
      # @param level [Integer] heading level 1-6
      # @param content [String] heading text
      # @param options [Hash] options passed to `text()`
      # @return [void]
      def heading(level, content, options = {})
        tag = :"H#{level}"
        if tagged?
          structure(tag) { text(content, options) }
        else
          text(content, options)
        end
      end

      # Render text wrapped in a paragraph structure element.
      #
      # @param content [String, nil] text to render. If nil, yields a block.
      # @param options [Hash] options passed to `text()`
      # @yield optional block for complex paragraph content
      # @return [void]
      def paragraph(content = nil, options = {}, &block)
        if tagged?
          if block
            structure(:P, &block)
          else
            structure(:P) { text(content, options) }
          end
        elsif block
          yield
        else
          text(content, options)
        end
      end

      # Render an image wrapped in a Figure structure element with alt text.
      #
      # @param alt_text [String] alternative text for the image
      # @yield block that calls `image()` or other drawing methods
      # @return [void]
      def figure(alt_text:, &block)
        if tagged?
          structure(:Figure, Alt: alt_text, &block)
        else
          yield
        end
      end
    end

    # Prepended onto {Prawn::Document#initialize} to support the
    # <tt>Prawn::Document.new(marked: true, language: 'en-US')</tt> API.
    # Tagging is opt-in: a document is tagged only when <tt>marked: true</tt> is
    # passed (matching the behavior of the section-508 forks).
    #
    # It strips the accessibility options before delegating to the original
    # initializer (so no change to +VALID_OPTIONS+ is needed), then wires up
    # tagging and runs the user block — in that order, so the block runs with
    # tagging already active.
    #
    # @api private
    module OptionInitializer
      def initialize(options = {}, &block)
        opts = options.dup
        marked = opts.delete(:marked)
        language = opts.delete(:language)

        # Delegate to the original initializer WITHOUT the block, so we can run
        # it ourselves after tagging is wired up.
        super(opts)

        install_accessibility(language) if marked

        return unless block

        block.arity < 1 ? instance_eval(&block) : block[self]
      end

      private

      # Set up tagged-PDF output: mark the catalog, create the structure tree,
      # bump the PDF version to 1.7, and finalize the tree at render time via
      # the renderer's public `before_render` hook.
      #
      # @param language [String, nil] optional document language (BCP 47 tag)
      # @return [void]
      def install_accessibility(language)
        catalog = state.store.root.data
        catalog[:MarkInfo] = { Marked: true }
        catalog[:Lang] = language if language

        @accessibility_structure_tree = Prawn::Accessibility::StructureTree.new(renderer)
        renderer.min_version(1.7)
        tree = @accessibility_structure_tree
        renderer.before_render { |_state| tree.finalize! }
      end
    end
  end
end

Prawn::Document.include(Prawn::Accessibility::DocumentExtensions)
Prawn::Document.prepend(Prawn::Accessibility::OptionInitializer)
