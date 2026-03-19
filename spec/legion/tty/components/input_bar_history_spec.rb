# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/input_bar'

RSpec.describe Legion::TTY::Components::InputBar, 'history' do
  let(:reader) { double('reader', read_line: 'test') }

  before do
    allow(reader).to receive(:on)
  end

  describe '#history' do
    it 'returns an array' do
      bar = described_class.new(name: 'Test', reader: reader)
      expect(bar.history).to be_an(Array)
    end

    it 'returns empty when reader has no history support' do
      plain_reader = double('plain_reader', read_line: 'x')
      bar = described_class.new(name: 'Test', reader: plain_reader)
      expect(bar.history).to eq([])
    end
  end
end
