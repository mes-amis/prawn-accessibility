# frozen_string_literal: true

require 'spec_helper'

# Tagging is opt-in: a document is tagged only when created with `tagged: true`.
# These specs guard that a document created WITHOUT it behaves exactly like
# stock Prawn (every patched method delegates to `super` on the untagged path),
# so adding this gem to a bundle changes nothing until a document opts in.
RSpec.describe 'Untagged output is unaffected by prawn-accessibility' do
  describe 'a plain document (no tagged: option)' do
    let(:pdf) { Prawn::Document.new }

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
  end

  describe 'a plain table' do
    it 'renders without any structure tags' do
      pdf = Prawn::Document.new
      pdf.table([%w[Name Age], %w[Alice 30]], header: true)
      output = pdf.render

      expect(output).to_not(include('/StructTreeRoot'))
      expect(output).to_not(include('/TR'))
      expect(output).to_not(include('/TH'))
      expect(output).to_not(include('/TD'))
    end

    it 'still flags header cells at construction (consistent whether tagged or not)' do
      pdf = Prawn::Document.new
      table = pdf.make_table([%w[Name Age], %w[Alice 30]], header: true)

      expect(table.cells[0, 0]).to be_header
      expect(table.cells[1, 0]).to_not(be_header)
    end
  end

  describe 'opting in with tagged: true' do
    it 'produces a 1.7 tagged PDF' do
      pdf = Prawn::Document.new(tagged: true)
      pdf.heading(1, 'Title')
      output = pdf.render

      expect(output).to start_with('%PDF-1.7')
      expect(output).to include('/MarkInfo')
      expect(output).to include('/StructTreeRoot')
    end
  end
end
