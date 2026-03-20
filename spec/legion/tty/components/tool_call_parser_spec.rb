# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/tool_call_parser'

RSpec.describe Legion::TTY::Components::ToolCallParser do
  let(:text_chunks) { [] }
  let(:tool_calls) { [] }
  let(:parser) do
    described_class.new(
      on_text: ->(text) { text_chunks << text },
      on_tool_call: ->(name:, args:) { tool_calls << { name: name, args: args } }
    )
  end

  describe '#feed with plain text' do
    it 'passes through text unchanged' do
      parser.feed('hello world')
      parser.flush
      expect(text_chunks.join).to eq('hello world')
      expect(tool_calls).to be_empty
    end

    it 'handles multiple feed calls' do
      parser.feed('hello ')
      parser.feed('world')
      parser.flush
      expect(text_chunks.join).to eq('hello world')
    end
  end

  describe '#feed with tool calls' do
    it 'parses a complete tool call block' do
      parser.feed('<tool_call>{"name": "shell", "arguments": {"command": "ls"}}</tool_call>')
      parser.flush
      expect(tool_calls.size).to eq(1)
      expect(tool_calls.first[:name]).to eq('shell')
      expect(tool_calls.first[:args]).to eq({ command: 'ls' })
      expect(text_chunks.join).to eq('')
    end

    it 'handles text before and after a tool call' do
      parser.feed('before <tool_call>{"name": "test", "arguments": {}}</tool_call> after')
      parser.flush
      expect(tool_calls.size).to eq(1)
      expect(tool_calls.first[:name]).to eq('test')
      expect(text_chunks.join).to eq('before  after')
    end

    it 'handles multiple tool calls in one feed' do
      input = '<tool_call>{"name": "a", "arguments": {}}</tool_call>' \
              'middle' \
              '<tool_call>{"name": "b", "arguments": {}}</tool_call>'
      parser.feed(input)
      parser.flush
      expect(tool_calls.size).to eq(2)
      expect(tool_calls.map { |t| t[:name] }).to eq(%w[a b])
      expect(text_chunks.join).to eq('middle')
    end

    it 'defaults missing arguments to empty hash' do
      parser.feed('<tool_call>{"name": "simple"}</tool_call>')
      parser.flush
      expect(tool_calls.first[:args]).to eq({})
    end
  end

  describe '#feed with split chunks' do
    it 'handles tag split across chunks' do
      parser.feed('hello <tool_')
      parser.feed('call>{"name": "split", "arguments": {}}</tool_call> done')
      parser.flush
      expect(tool_calls.size).to eq(1)
      expect(tool_calls.first[:name]).to eq('split')
      expect(text_chunks.join).to eq('hello  done')
    end

    it 'handles close tag split across chunks' do
      parser.feed('<tool_call>{"name": "x", "arguments": {}}</tool_')
      parser.feed('call>')
      parser.flush
      expect(tool_calls.size).to eq(1)
      expect(tool_calls.first[:name]).to eq('x')
    end

    it 'handles JSON split across chunks' do
      parser.feed('<tool_call>{"name": "sp')
      parser.feed('lit", "arguments": {"key": "val"}}</tool_call>')
      parser.flush
      expect(tool_calls.size).to eq(1)
      expect(tool_calls.first[:name]).to eq('split')
      expect(tool_calls.first[:args]).to eq({ key: 'val' })
    end
  end

  describe 'malformed input' do
    it 'flushes malformed JSON as text' do
      parser.feed('<tool_call>not json</tool_call>')
      parser.flush
      expect(tool_calls).to be_empty
      expect(text_chunks.join).to eq('<tool_call>not json</tool_call>')
    end

    it 'flushes tool call without name as text' do
      parser.feed('<tool_call>{"arguments": {"a": 1}}</tool_call>')
      parser.flush
      expect(tool_calls).to be_empty
      expect(text_chunks.join).to include('<tool_call>')
    end

    it 'flushes buffer on overflow' do
      large = 'x' * (described_class::MAX_BUFFER + 1)
      parser.feed("<tool_call>#{large}")
      parser.flush
      expect(tool_calls).to be_empty
      expect(text_chunks.join).to include('<tool_call>')
    end
  end

  describe '#flush' do
    it 'emits buffered partial tag as text' do
      parser.feed('text ending with <tool_')
      parser.flush
      expect(text_chunks.join).to eq('text ending with <tool_')
    end

    it 'is safe to call when empty' do
      parser.flush
      expect(text_chunks).to be_empty
    end
  end

  describe '#reset' do
    it 'clears all state' do
      parser.feed('<tool_call>{"name": "x"')
      parser.reset
      parser.feed('clean text')
      parser.flush
      expect(tool_calls).to be_empty
      expect(text_chunks.join).to eq('clean text')
    end
  end
end
