# frozen_string_literal: true

require 'spec_helper'

# A marked-content sequence must begin and end in the same content stream
# (ISO 32000-1, 14.6). When a block's content flows onto another page, the
# sequence is closed on the old page and reopened on the new one with a fresh
# MCID that refers back to the same structure element.
RSpec.describe 'Marked content across page changes' do
  let(:pdf) { Prawn::Document.new(tagged: true) }
  let(:long_text) { 'Long paragraph text. ' * 400 }

  def page_streams(doc)
    doc.state.pages.map { |page| page.content.stream.filtered_stream }
  end

  def expect_balanced(doc)
    page_streams(doc).each_with_index do |stream, i|
      opened = stream.scan(/\bB(?:D|M)C\b/).size
      closed = stream.scan(/\bEMC\b/).size
      expect(closed).to eq(opened), "page #{i + 1}: #{opened} BDC/BMC vs #{closed} EMC"
    end
  end

  def mcrs(elem_ref)
    elem_ref.data[:K].select { |kid| kid.is_a?(Hash) && kid[:Type] == :MCR }
  end

  def first_document_kid(doc)
    doc.structure_tree.document_elem_ref.data[:K].first
  end

  describe 'a paragraph that flows onto new pages' do
    before { pdf.paragraph(long_text) }

    it 'spans more than one page' do
      expect(pdf.page_count).to be > 1
    end

    it 'balances BDC/EMC in every page content stream' do
      expect_balanced(pdf)
    end

    it 'references marked content on every page from the same P element' do
      p_elem = first_document_kid(pdf)
      pages = mcrs(p_elem).map { |mcr| mcr[:Pg] }.uniq

      expect(p_elem.data[:S]).to eq(:P)
      expect(pages).to eq(pdf.state.pages.map(&:dictionary))
    end

    it 'gives the continuation a fresh MCID on the new page' do
      p_elem = first_document_kid(pdf)
      second_page = pdf.state.pages[1]
      mcr = mcrs(p_elem).find { |m| m[:Pg] == second_page.dictionary }

      expect(mcr[:MCID]).to eq(0)
      expect(page_streams(pdf)[1]).to include('/P << /MCID 0')
    end

    it 'maps the continuation MCID to the same element in the ParentTree' do
      p_elem = first_document_kid(pdf)
      pdf.render

      nums = pdf.structure_tree.root_ref.data[:ParentTree].data[:Nums]
      parents = nums.each_slice(2).to_h
      pdf.state.pages.each do |page|
        expect(parents.fetch(page.dictionary.data[:StructParents]).data).to eq([p_elem])
      end
    end
  end

  describe 'nested sequences' do
    it 'closes inner sequences first and reopens them outermost first' do
      pdf.paragraph do
        pdf.text('Lead-in.')
        pdf.structure(:Span) { pdf.text(long_text) }
      end

      expect_balanced(pdf)
      second = page_streams(pdf)[1]
      expect(second).to match(%r{/P << /MCID 0\s+>> BDC\s+/Span << /MCID 1\s+>> BDC})
    end
  end

  describe 'artifacts that flow onto new pages' do
    it 'balances untyped (BMC) artifacts' do
      pdf.artifact { pdf.text(long_text) }
      expect_balanced(pdf)
    end

    it 'reopens typed (BDC) artifacts with their type' do
      pdf.artifact(type: :Pagination) { pdf.text(long_text) }

      expect_balanced(pdf)
      expect(page_streams(pdf)[1]).to include('/Artifact << /Type /Pagination')
    end
  end

  describe 'go_to_page' do
    it 'balances content that flows onto an existing page' do
      pdf.start_new_page
      pdf.go_to_page(1)
      pdf.paragraph(long_text)

      expect(pdf.page_count).to eq(2)
      expect_balanced(pdf)
      expect(mcrs(first_document_kid(pdf)).map { |m| m[:Pg] }.uniq.size).to eq(2)
    end

    it 'continues MCIDs after those already used on the revisited page' do
      pdf.paragraph('First page.')
      pdf.start_new_page
      pdf.paragraph('Second page.')
      pdf.go_to_page(1)
      pdf.paragraph(long_text)

      expect(page_streams(pdf)[1]).to include('/P << /MCID 1')
      expect_balanced(pdf)
    end

    it 'leaves open sequences alone when the target is the current page' do
      pdf.paragraph do
        pdf.text('Before.')
        pdf.go_to_page(1)
        pdf.text('After.')
      end

      expect(page_streams(pdf).first.scan(/\bBDC\b/).size).to eq(1)
    end
  end

  describe 'page changes outside marked content' do
    it 'emits no extra operators' do
      pdf.paragraph('Page one.')
      pdf.start_new_page
      pdf.paragraph('Page two.')

      page_streams(pdf).each do |stream|
        expect(stream.scan(/\bBDC\b/).size).to eq(1)
      end
    end
  end
end
