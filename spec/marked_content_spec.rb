# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Prawn::Accessibility::MarkedContent do
  # The mixin only requires its host to respond to #add_content, so we can
  # exercise it against a tiny emitter without patching PDF::Core::Renderer.
  let(:emitter) do
    Class.new do
      include Prawn::Accessibility::MarkedContent

      attr_reader :content

      def initialize
        @content = +''
      end

      def add_content(str)
        @content << str << "\n"
      end
    end.new
  end

  describe '#begin_marked_content' do
    it 'emits BMC operator with tag' do
      emitter.begin_marked_content(:P)
      expect(emitter.content).to include('/P BMC')
    end
  end

  describe '#end_marked_content' do
    it 'emits EMC operator' do
      emitter.end_marked_content
      expect(emitter.content).to include('EMC')
    end
  end

  describe '#begin_marked_content_with_properties' do
    it 'emits BDC operator with tag and properties' do
      emitter.begin_marked_content_with_properties(:P, { MCID: 0 })
      expect(emitter.content).to include('/P << /MCID 0')
      expect(emitter.content).to include('BDC')
    end
  end

  describe '#marked_content_sequence' do
    it 'wraps content in BMC/EMC' do
      emitter.marked_content_sequence(:Artifact) do
        emitter.add_content('some content')
      end

      expect(emitter.content).to include('/Artifact BMC')
      expect(emitter.content).to include('some content')
      expect(emitter.content).to include('EMC')
    end
  end

  describe '#marked_content_sequence_with_properties' do
    it 'wraps content in BDC/EMC with properties' do
      emitter.marked_content_sequence_with_properties(:P, { MCID: 0 }) do
        emitter.add_content('tagged text')
      end

      expect(emitter.content).to include('/P << /MCID 0')
      expect(emitter.content).to include('BDC')
      expect(emitter.content).to include('tagged text')
      expect(emitter.content).to include('EMC')
    end
  end
end
