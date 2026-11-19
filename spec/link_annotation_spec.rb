# frozen_string_literal: true

require 'spec_helper'

# Link annotations are part of the logical structure (ISO 32000-1, 14.8.4.4.2;
# ISO 14289-1, 7.18.5): each one is referenced from a <Link> structure element
# by an OBJR, carries a /StructParent key into the ParentTree, and has an
# alternate description in /Contents.
RSpec.describe 'Link annotations' do
  let(:pdf) { Prawn::Document.new(tagged: true) }

  def annotations(doc = pdf)
    doc.state.pages.flat_map { |page| page.dictionary.data[:Annots] || [] }
  end

  def kids(elem_ref)
    elem_ref.data[:K].grep(PDF::Core::Reference)
  end

  def objrs(elem_ref)
    elem_ref.data[:K].select { |kid| kid.is_a?(Hash) && kid[:Type] == :OBJR }
  end

  def parent_tree(doc = pdf)
    doc.render
    doc.structure_tree.root_ref.data[:ParentTree].data[:Nums].each_slice(2).to_h
  end

  def link_text(href = 'https://example.com', label = 'Example')
    %(See <link href="#{href}">#{label}</link>.)
  end

  describe 'a link inside a paragraph' do
    before { pdf.paragraph(link_text, inline_format: true) }

    let(:annotation) { annotations.last }
    let(:paragraph) { kids(pdf.structure_tree.document_elem_ref).first }
    let(:link) { kids(paragraph).first }

    it 'adds a Link element as a child of the enclosing element' do
      expect(paragraph.data[:S]).to eq(:P)
      expect(link.data[:S]).to eq(:Link)
      expect(link.data[:P]).to eq(paragraph)
    end

    it 'references the annotation from the Link element with an OBJR' do
      expect(objrs(link)).to eq([{ Type: :OBJR, Obj: annotation, Pg: pdf.state.page.dictionary }])
    end

    it 'gives the annotation a StructParent that maps directly to the Link element' do
      key = annotation.data[:StructParent]

      expect(key).to be_a(Integer)
      expect(parent_tree[key]).to eq(link)
    end

    it 'uses the URI as /Contents by default' do
      expect(annotation.data[:Contents]).to eq('https://example.com')
    end
  end

  describe 'StructParent keys' do
    it 'shares one key space between pages and annotations' do
      pdf.paragraph(link_text, inline_format: true)
      pdf.start_new_page
      pdf.paragraph(link_text('https://example.org'), inline_format: true)

      page_keys = pdf.state.pages.map { |page| page.dictionary.data[:StructParents] }
      annot_keys = annotations.map { |annot| annot.data[:StructParent] }
      keys = page_keys + annot_keys

      expect(keys.uniq.size).to eq(keys.size)
      expect(keys.sort).to eq((0...keys.size).to_a)
    end

    it 'maps page keys to MCID arrays and annotation keys to elements' do
      pdf.paragraph(link_text, inline_format: true)
      tree = parent_tree

      page_key = pdf.state.page.dictionary.data[:StructParents]
      annot_key = annotations.last.data[:StructParent]
      expect(tree[page_key].data).to be_an(Array)
      expect(tree[annot_key].data[:S]).to eq(:Link)
    end

    it 'sets ParentTreeNextKey past the last key used' do
      pdf.paragraph(link_text, inline_format: true)
      pdf.render

      expect(pdf.structure_tree.root_ref.data[:ParentTreeNextKey]).to eq(2)
    end
  end

  describe '#link' do
    it 'puts the annotation in the Link element it opens' do
      pdf.structure_container(:P) do
        pdf.link('Example website') { pdf.text(link_text, inline_format: true) }
      end

      paragraph = kids(pdf.structure_tree.document_elem_ref).first
      link = kids(paragraph).first
      expect(kids(paragraph).map { |kid| kid.data[:S] }).to eq([:Link])
      expect(kids(link)).to be_empty
      expect(objrs(link).map { |objr| objr[:Obj] }).to eq([annotations.last])
    end

    it 'uses the description as /Contents' do
      pdf.link('Example website') { pdf.text(link_text, inline_format: true) }

      expect(annotations.last.data[:Contents]).to eq('Example website')
    end

    it 'falls back to the URI without a description' do
      pdf.link { pdf.text(link_text, inline_format: true) }

      expect(annotations.last.data[:Contents]).to eq('https://example.com')
    end

    it 'does not leak the description to later links' do
      pdf.link('Example website') { pdf.text(link_text, inline_format: true) }
      pdf.paragraph(link_text('https://example.org'), inline_format: true)

      expect(annotations.last.data[:Contents]).to eq('https://example.org')
    end

    it 'yields without tagging in an untagged document' do
      plain = Prawn::Document.new
      plain.link('Example website') { plain.text(link_text, inline_format: true) }

      expect(annotations(plain).last.data).to_not(include(:StructParent, :Contents))
      expect(plain.render).to_not(include('/StructTreeRoot'))
    end
  end

  describe '/Contents' do
    it 'keeps a /Contents supplied by the caller' do
      pdf.link_annotation([0, 0, 10, 10], Contents: 'Given', A: { S: :URI, URI: 'https://x.test' })

      expect(annotations.last.data[:Contents]).to eq('Given')
    end
  end

  describe 'other annotations' do
    it 'are left alone' do
      pdf.text_annotation([0, 0, 10, 10], 'A note')

      expect(annotations.last.data).to_not(include(:StructParent))
    end
  end

  describe 'page tab order' do
    it 'sets /Tabs /S on every page' do
      pdf.paragraph(link_text, inline_format: true)
      pdf.start_new_page
      pdf.render

      expect(pdf.state.pages.map { |page| page.dictionary.data[:Tabs] }).to eq(%i[S S])
    end
  end
end
