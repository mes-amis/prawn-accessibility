# frozen_string_literal: true

require 'spec_helper'

# These specs guard the core promise of the layering approach: when a document
# is NOT created with `marked: true`, prawn / pdf-core / prawn-table must behave
# exactly as they do upstream. Every patched method delegates to `super` in the
# untagged path, so none of the tagged-PDF machinery should appear in output.
RSpec.describe 'Untagged output is unaffected by prawn-accessibility' do
  describe 'a plain document' do
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

    it 'still produces a valid PDF at the default version' do
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

    it 'never flags header cells for an untagged document' do
      pdf = Prawn::Document.new
      # Draws the table; because the document is not tagged, header marking is
      # skipped entirely — tagging (and its side effects) are fully opt-in.
      table = pdf.table([%w[Name Age], %w[Alice 30]], header: true)

      expect(table.cells[0, 0]).to_not(be_header)
      expect(table.cells[1, 0]).to_not(be_header)
    end
  end

  describe 'opting in still works alongside the untagged path' do
    it 'produces a 1.7 tagged PDF only when marked' do
      tagged = Prawn::Document.new(marked: true)
      tagged.heading(1, 'Title')
      expect(tagged.render).to start_with('%PDF-1.7')

      plain = Prawn::Document.new
      plain.text('Title')
      expect(plain.render).to_not(start_with('%PDF-1.7'))
    end
  end
end
