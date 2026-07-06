# frozen_string_literal: true

require 'pdf/core'
require_relative 'marked_content'
require_relative 'structure_tree'

module Prawn
  module Accessibility
    # Patches applied to the published +pdf-core+ gem to add tagged-PDF
    # support. All patches are additive or +prepend+-based: the original
    # (untagged) behavior is preserved and only diverges when a document is
    # created with <tt>marked: true</tt>.
    #
    # @api private
    module PDFCore
      # Prepended onto {PDF::Core::DocumentState#initialize}. Threads the
      # +:marked+ and +:language+ options through to the object store's
      # catalog after the original initializer has built the store.
      #
      # @api private
      module DocumentStatePatch
        def initialize(options)
          super

          @store.root.data[:MarkInfo] = { Marked: true } if options[:marked]
          @store.root.data[:Lang] = options[:language] if options[:language]
        end
      end

      # Prepended onto {PDF::Core::Renderer#initialize}. When the document is
      # marked, wires up a {PDF::Core::StructureTree}, schedules its
      # finalization before render, and bumps the PDF version to 1.7.
      #
      # @api private
      module RendererPatch
        def initialize(state)
          super

          return unless state.store.marked?

          @structure_tree = PDF::Core::StructureTree.new(self)
          before_render { |_doc_state| @structure_tree.finalize! }
          min_version(1.7)
        end

        # The structure tree for this document, or nil if not tagged.
        #
        # @return [PDF::Core::StructureTree, nil]
        attr_reader :structure_tree

        # Whether this document is marked (tagged for accessibility).
        #
        # @return [Boolean]
        def marked?
          state.store.marked?
        end
      end
    end
  end
end

# --- Additive re-opens ------------------------------------------------------

module PDF
  module Core
    class ObjectStore
      # Whether this document is marked (tagged for accessibility).
      #
      # @return [Boolean]
      def marked?
        root.data.key?(:MarkInfo) && root.data[:MarkInfo][:Marked] == true
      end
    end
  end
end

PDF::Core::Renderer.include(PDF::Core::MarkedContent)
PDF::Core::DocumentState.prepend(Prawn::Accessibility::PDFCore::DocumentStatePatch)
PDF::Core::Renderer.prepend(Prawn::Accessibility::PDFCore::RendererPatch)
