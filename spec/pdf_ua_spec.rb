# frozen_string_literal: true

require 'spec_helper'

# PDF/UA identification (ISO 14289-1, 5 and 7.1): an XMP metadata stream with
# dc:title and pdfuaid:part, and a ViewerPreferences DisplayDocTitle entry.
RSpec.describe 'PDF/UA identification' do
  let(:info) { { Title: 'Annual Report' } }
  let(:pdf) { Prawn::Document.new(tagged: true, pdf_ua: true, info: info) }
  let(:catalog) { pdf.state.store.root.data }

  def metadata(doc = pdf)
    doc.render
    doc.state.store.root.data[:Metadata]
  end

  def xmp(doc = pdf)
    metadata(doc).stream.filtered_stream.dup.force_encoding(Encoding::UTF_8)
  end

  describe 'with pdf_ua: true' do
    before { pdf.paragraph('Body.') }

    it 'sets DisplayDocTitle in ViewerPreferences' do
      expect(catalog[:ViewerPreferences]).to eq(DisplayDocTitle: true)
    end

    it 'attaches an XMP metadata stream to the catalog' do
      expect(metadata.data).to include(Type: :Metadata, Subtype: :XML)
    end

    it 'declares PDF/UA-1 conformance' do
      expect(xmp).to include('xmlns:pdfuaid="http://www.aiim.org/pdfua/ns/id/"')
      expect(xmp).to include('<pdfuaid:part>1</pdfuaid:part>')
    end

    it 'carries the document title as dc:title' do
      expect(xmp).to include('<rdf:li xml:lang="x-default">Annual Report</rdf:li>')
    end

    it 'is a complete XMP packet' do
      expect(xmp).to start_with(%(<?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?>))
      expect(xmp.strip).to end_with('<?xpacket end="w"?>')
    end

    it 'leaves the metadata stream uncompressed' do
      doc = Prawn::Document.new(tagged: true, pdf_ua: true, info: info, compress: true)
      doc.paragraph('Body.')

      expect(metadata(doc).data).to_not(include(:Filter))
      expect(xmp(doc)).to include('<pdfuaid:part>1</pdfuaid:part>')
    end

    it 'renders as PDF 1.7' do
      expect(pdf.render).to start_with('%PDF-1.7')
    end
  end

  describe 'the title' do
    it 'is XML-escaped' do
      info[:Title] = %(Q&A <draft> "one" 'two')

      expect(xmp).to include(
        '<rdf:li xml:lang="x-default">Q&amp;A &lt;draft&gt; &quot;one&quot; &apos;two&apos;</rdf:li>',
      )
    end

    it 'keeps non-ASCII characters as UTF-8' do
      info[:Title] = 'Résumé — 2026'

      expect(xmp).to include('Résumé — 2026')
    end

    it 'is omitted when the document has no Title' do
      doc = Prawn::Document.new(tagged: true, pdf_ua: true)

      expect(xmp(doc)).to_not(include('dc:title'))
      expect(xmp(doc)).to include('<pdfuaid:part>1</pdfuaid:part>')
    end
  end

  describe 'without pdf_ua:' do
    it 'adds no metadata stream or viewer preferences to a tagged document' do
      doc = Prawn::Document.new(tagged: true, info: info)
      doc.paragraph('Body.')
      doc.render

      expect(doc.state.store.root.data).to_not(include(:Metadata, :ViewerPreferences))
    end
  end

  describe 'pdf_ua: true without tagged: true' do
    it 'raises, since PDF/UA requires a tagged PDF' do
      expect { Prawn::Document.new(pdf_ua: true) }
        .to raise_error(ArgumentError, /pdf_ua: true requires tagged: true/)
    end
  end

  describe 'pdf_ua: false' do
    it 'is accepted and adds nothing' do
      doc = Prawn::Document.new(pdf_ua: false)
      doc.render

      expect(doc.state.store.root.data).to_not(include(:Metadata, :ViewerPreferences))
    end
  end
end
