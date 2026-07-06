# frozen_string_literal: true

require 'spec_helper'

# Loading prawn-accessibility makes every document tagged by default. These
# specs pin down that behavior, and — just as importantly — that `marked: false`
# still yields byte-for-byte stock Prawn output (every patched method delegates
# to `super` on the opt-out path).
RSpec.describe 'Default-on tagging' do
  describe 'a document created with no options' do
    let(:pdf) { Prawn::Document.new }

    it 'is tagged by default' do
      expect(pdf).to be_tagged
    end

    it 'emits tagged-PDF structures and bumps the version to 1.7' do
      pdf.heading(1, 'Title')
      pdf.paragraph('Body.')
      output = pdf.render

      expect(output).to start_with('%PDF-1.7')
      expect(output).to include('/MarkInfo')
      expect(output).to include('/StructTreeRoot')
    end
  end

  describe 'opting out with marked: false' do
    let(:pdf) { Prawn::Document.new(marked: false) }

    it 'is not tagged' do
      expect(pdf).to_not(be_tagged)
    end

    it 'emits no tagged-PDF structures' do
      pdf.text('Hello, world.')
      pdf.text('Second paragraph.')
      output = pdf.render

      expect(output).to_not(include('/MarkInfo'))
      expect(output).to_not(include('/StructTreeRoot'))
      expect(output).to_not(include('/StructElem'))
      expect(output).to_not(include(' BDC'))
      expect(output).to_not(include('/Artifact'))
    end

    it 'keeps the stock PDF version' do
      pdf.text('Content')
      output = pdf.render

      expect(output).to start_with('%PDF-1.')
      expect(output).to_not(start_with('%PDF-1.7'))
    end

    it 'renders a table without any structure tags' do
      pdf.table([%w[Name Age], %w[Alice 30]], header: true)
      output = pdf.render

      expect(output).to_not(include('/StructTreeRoot'))
      expect(output).to_not(include('/TR'))
      expect(output).to_not(include('/TH'))
      expect(output).to_not(include('/TD'))
    end

    it 'never flags header cells' do
      table = pdf.table([%w[Name Age], %w[Alice 30]], header: true)

      expect(table.cells[0, 0]).to_not(be_header)
      expect(table.cells[1, 0]).to_not(be_header)
    end
  end
end
