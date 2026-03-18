# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/input_bar'

RSpec.describe Legion::TTY::Components::InputBar do
  let(:mock_reader) { double('reader', read_line: 'hello') }
  subject(:input_bar) { described_class.new(name: 'Alice', reader: mock_reader) }

  describe '#prompt_string' do
    it 'includes the user name' do
      expect(input_bar.prompt_string).to include('Alice')
    end

    it 'includes the glyph character >' do
      expect(input_bar.prompt_string).to include('>')
    end

    it 'returns a string' do
      expect(input_bar.prompt_string).to be_a(String)
    end
  end

  describe '#read_line' do
    it 'delegates to the reader' do
      expect(mock_reader).to receive(:read_line).with(input_bar.prompt_string)
      input_bar.read_line
    end

    it 'returns the reader result' do
      expect(input_bar.read_line).to eq('hello')
    end
  end

  describe 'thinking state' do
    it 'starts not thinking' do
      expect(input_bar.thinking?).to be false
    end

    it 'show_thinking sets thinking to true' do
      input_bar.show_thinking
      expect(input_bar.thinking?).to be true
    end

    it 'clear_thinking sets thinking to false' do
      input_bar.show_thinking
      input_bar.clear_thinking
      expect(input_bar.thinking?).to be false
    end

    it 'toggles correctly between states' do
      expect(input_bar.thinking?).to be false
      input_bar.show_thinking
      expect(input_bar.thinking?).to be true
      input_bar.clear_thinking
      expect(input_bar.thinking?).to be false
    end
  end
end
