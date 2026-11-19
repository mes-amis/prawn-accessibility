# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Table Accessibility' do
  let(:pdf) { Prawn::Document.new(tagged: true, language: 'en-US', margin: 0) }

  describe 'tagged table rendering' do
    it 'wraps the table in a Table structure element' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/Table')
      expect(output).to include('/StructTreeRoot')
    end

    it 'creates TR structure elements for each row' do
      data = [['A', 'B'], ['C', 'D']]
      pdf.table(data)
      output = pdf.render

      expect(output).to include('/TR')
    end

    it 'creates TH elements for header cells' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/TH')
    end

    it 'creates TD elements for data cells' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/TD')
    end

    it 'sets Scope on TH elements' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/Scope /Column')
    end

    it 'marks all cells as TD when no header is set' do
      data = [['A', 'B'], ['C', 'D']]
      pdf.table(data)
      output = pdf.render

      expect(output).to include('/TD')
      expect(output).not_to include('/TH')
    end

    it 'supports multiple header rows' do
      data = [['Group', ''], ['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: 2)
      output = pdf.render

      expect(output).to include('/TH')
    end
  end

  describe 'untagged table rendering' do
    it 'does not emit structure tags when not tagged' do
      plain_pdf = Prawn::Document.new(margin: 0)
      data = [['Name', 'Age'], ['Alice', '30']]
      plain_pdf.table(data, header: true)
      output = plain_pdf.render

      expect(output).not_to include('/StructTreeRoot')
      expect(output).not_to include('/TH')
      expect(output).not_to include('/TD')
    end
  end

  describe 'Cell#header?' do
    # Header flags are applied at construction, so they are available from
    # #make_table without drawing.
    it 'returns true for cells in header rows' do
      data = [['Name', 'Age'], ['Alice', '30']]
      table = pdf.make_table(data, header: true)

      header_cell = table.cells[0, 0]
      data_cell = table.cells[1, 0]

      expect(header_cell).to be_header
      expect(data_cell).not_to be_header
    end

    it 'returns false when no header is set' do
      data = [['A', 'B'], ['C', 'D']]
      table = pdf.make_table(data)

      expect(table.cells[0, 0]).not_to be_header
    end
  end

  describe 'a cell containing a subtable' do
    def draw_nested(doc)
      inner = doc.make_table([%w[x y]], cell_style: { background_color: 'EEEEEE' })
      doc.table([['A', 'B'], ['C', inner]], cell_style: { background_color: 'DDDDDD' })
    end

    # Each marked-content operator on the page, as [:open, tag, mcid] or [:close].
    def marked_content_ops(doc)
      stream = doc.state.page.content.stream.filtered_stream
      stream.scan(%r{/(\w+)\s*(<<[^>]*>>)?\s*B[DM]C|\bEMC\b}).map do |tag, props|
        tag ? [:open, tag, props.to_s[/MCID (\d+)/, 1]] : [:close]
      end
    end

    def struct_kids(elem_ref)
      elem_ref.data[:K].grep(PDF::Core::Reference)
    end

    before { draw_nested(pdf) }

    it 'opens no marked content inside a tagged cell sequence' do
      stack = []
      marked_content_ops(pdf).each do |op, tag, mcid|
        if op == :close
          stack.pop
        else
          expect(stack.last).to be_nil, "#{tag} opened inside tagged #{stack.last}"
          stack.push(mcid && tag)
        end
      end
    end

    it 'makes the outer TD a container of the inner Table' do
      outer_table = struct_kids(pdf.structure_tree.document_elem_ref).first
      second_row = struct_kids(outer_table)[1]
      subtable_td = struct_kids(second_row)[1]

      expect(subtable_td.data[:S]).to eq(:TD)
      expect(subtable_td.data[:K].grep(Hash)).to be_empty
      expect(struct_kids(subtable_td).map { |kid| kid.data[:S] }).to eq([:Table])
    end

    it 'paints in the same order as an untagged table' do
      plain = Prawn::Document.new(margin: 0)
      draw_nested(plain)

      drawing = lambda do |doc|
        doc.state.page.content.stream.filtered_stream
           .gsub(%r{/\w+\s*(<<[^>]*>>)?\s*B[DM]C|\bEMC\b}, '').split
      end
      expect(drawing.call(pdf)).to eq(drawing.call(plain))
    end
  end
end
