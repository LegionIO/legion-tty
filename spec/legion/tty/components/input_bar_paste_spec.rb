# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/input_bar'

RSpec.describe Legion::TTY::Components::InputBar, 'paste handling' do
  subject(:input_bar) { described_class.new(name: 'Alice') }

  describe '#handle_key with paste event' do
    it 'inserts single-line paste into buffer' do
      input_bar.handle_key({ paste: 'hello world' })
      expect(input_bar.buffer).to eq('hello world')
    end

    it 'inserts multi-line paste replacing newlines with spaces' do
      input_bar.handle_key({ paste: "line1\nline2\nline3" })
      expect(input_bar.buffer).to eq('line1 line2 line3')
    end

    it 'does not trigger submit on paste with newlines' do
      result = input_bar.handle_key({ paste: "hello\nworld" })
      expect(result).to eq(:handled)
      expect(input_bar.buffer).to eq('hello world')
    end

    it 'inserts paste at cursor position' do
      input_bar.handle_key('a')
      input_bar.handle_key('b')
      input_bar.handle_key(:left)
      input_bar.handle_key({ paste: 'XY' })
      expect(input_bar.buffer).to eq('aXYb')
    end

    it 'handles empty paste gracefully' do
      result = input_bar.handle_key({ paste: '' })
      expect(result).to eq(:handled)
      expect(input_bar.buffer).to eq('')
    end

    it 'handles paste with carriage returns' do
      input_bar.handle_key({ paste: "line1\r\nline2" })
      expect(input_bar.buffer).to eq('line1 line2')
    end

    it 'appends to existing buffer content' do
      input_bar.handle_key('>')
      input_bar.handle_key(' ')
      input_bar.handle_key({ paste: 'pasted text' })
      expect(input_bar.buffer).to eq('> pasted text')
    end
  end
end
