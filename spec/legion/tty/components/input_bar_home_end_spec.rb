# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/input_bar'

RSpec.describe Legion::TTY::Components::InputBar, 'Home/End passthrough' do
  let(:reader) { double('reader', read_line: nil) }

  before { allow(reader).to receive(:on) }

  subject(:bar) { described_class.new(name: 'Test', reader: reader) }

  describe ':home when buffer is empty' do
    it 'returns :pass so the screen can handle it' do
      expect(bar.handle_key(:home)).to eq(:pass)
    end
  end

  describe ':home when buffer has text' do
    before do
      bar.handle_key('h')
      bar.handle_key('i')
    end

    it 'returns :handled and moves cursor to start' do
      expect(bar.handle_key(:home)).to eq(:handled)
      expect(bar.cursor_column).to eq(bar.send(:prompt_plain_length))
    end
  end

  describe ':end when buffer is empty' do
    it 'returns :pass so the screen can handle it' do
      expect(bar.handle_key(:end)).to eq(:pass)
    end
  end

  describe ':end when buffer has text' do
    before do
      bar.handle_key('h')
      bar.handle_key('i')
    end

    it 'returns :handled and moves cursor to end' do
      bar.handle_key(:home)
      expect(bar.handle_key(:end)).to eq(:handled)
      expect(bar.cursor_column).to eq(bar.send(:prompt_plain_length) + 2)
    end
  end

  describe ':ctrl_a always moves to start' do
    it 'returns :handled even with empty buffer' do
      expect(bar.handle_key(:ctrl_a)).to eq(:handled)
    end
  end

  describe ':ctrl_e always moves to end' do
    it 'returns :handled even with empty buffer' do
      expect(bar.handle_key(:ctrl_e)).to eq(:handled)
    end
  end
end
