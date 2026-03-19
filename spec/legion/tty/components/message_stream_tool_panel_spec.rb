# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/message_stream'

RSpec.describe Legion::TTY::Components::MessageStream, 'tool panels' do
  describe '#add_tool_call' do
    it 'adds a tool panel message' do
      stream = described_class.new
      stream.add_tool_call(name: 'search_files', args: { query: 'test' })
      msg = stream.messages.last
      expect(msg[:role]).to eq(:tool)
      expect(msg[:tool_panel]).to be true
    end
  end

  describe '#update_tool_call' do
    it 'updates the status of a tool panel' do
      stream = described_class.new
      stream.add_tool_call(name: 'search_files', args: { query: 'test' })
      stream.update_tool_call(name: 'search_files', status: :complete, duration: 1.5)
      panel = stream.messages.last[:content]
      expect(panel.instance_variable_get(:@status)).to eq(:complete)
      expect(panel.instance_variable_get(:@duration)).to eq(1.5)
    end

    it 'does nothing when tool not found' do
      stream = described_class.new
      expect { stream.update_tool_call(name: 'nope', status: :failed) }.not_to raise_error
    end
  end
end
