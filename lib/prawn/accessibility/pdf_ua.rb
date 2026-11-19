# frozen_string_literal: true

module Prawn
  module Accessibility
    # PDF/UA-1 identification (ISO 14289-1, 5 and 7.1), applied to a tagged
    # document created with <tt>pdf_ua: true</tt>:
    #
    # * the Catalog's ViewerPreferences get <tt>DisplayDocTitle true</tt>, and
    # * at render time an XMP metadata stream (Type /Metadata, Subtype /XML)
    #   carrying <tt>dc:title</tt> (from the document info's +:Title+) and
    #   <tt>pdfuaid:part 1</tt> is attached to the Catalog as /Metadata.
    #
    # This only *declares* conformance; the document's content must still be
    # fully tagged for the declaration to be true.
    #
    # @api private
    module PdfUa
      XMP_TEMPLATE = <<~XMP
        <?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:pdfuaid="http://www.aiim.org/pdfua/ns/id/">
        %<title>s      <pdfuaid:part>1</pdfuaid:part>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
      XMP

      DC_TITLE = <<-XMP
      <dc:title><rdf:Alt><rdf:li xml:lang="x-default">%<title>s</rdf:li></rdf:Alt></dc:title>
      XMP

      XML_ESCAPES = {
        '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;',
      }.freeze

      module_function

      # Set DisplayDocTitle now and attach the XMP metadata at render time,
      # once the document info (and so the title) is final.
      #
      # @param renderer [PDF::Core::Renderer]
      # @return [void]
      def install(renderer)
        catalog = renderer.state.store.root.data
        preferences = catalog[:ViewerPreferences] || {}
        catalog[:ViewerPreferences] = preferences.merge(DisplayDocTitle: true)
        renderer.before_render { |state| attach_metadata(renderer, state) }
      end

      # @param renderer [PDF::Core::Renderer]
      # @param state [PDF::Core::DocumentState]
      # @return [void]
      def attach_metadata(renderer, state)
        metadata = renderer.ref!(Type: :Metadata, Subtype: :XML)
        metadata.stream << xmp(state.store.info.data[:Title]).b
        state.store.root.data[:Metadata] = metadata
      end

      # The XMP packet for a document with the given title.
      #
      # @param title [String, nil] document title; dc:title is omitted if blank
      # @return [String] UTF-8 XMP packet
      def xmp(title)
        title = title.to_s.encode(::Encoding::UTF_8)
        format(XMP_TEMPLATE, title: title.empty? ? '' : format(DC_TITLE, title: xml_escape(title)))
      end

      # @param text [String]
      # @return [String]
      def xml_escape(text)
        text.gsub(/[&<>"']/, XML_ESCAPES)
      end
    end
  end
end
