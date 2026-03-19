# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/message_stream'

RSpec.describe Legion::TTY::Components::MessageStream do
  subject(:stream) { described_class.new }

  describe '#initialize' do
    it 'starts with an empty messages array' do
      expect(stream.messages).to eq([])
    end

    it 'starts with scroll_offset of 0' do
      expect(stream.scroll_offset).to eq(0)
    end
  end

  describe '#add_message' do
    it 'adds a message to the messages array' do
      stream.add_message(role: :user, content: 'Hello')
      expect(stream.messages.size).to eq(1)
    end

    it 'stores the role and content' do
      stream.add_message(role: :assistant, content: 'Hi there')
      msg = stream.messages.first
      expect(msg[:role]).to eq(:assistant)
      expect(msg[:content]).to eq('Hi there')
    end

    it 'initializes tool_panels as empty array' do
      stream.add_message(role: :user, content: 'test')
      expect(stream.messages.first[:tool_panels]).to eq([])
    end

    it 'adds multiple messages in order' do
      stream.add_message(role: :user, content: 'first')
      stream.add_message(role: :assistant, content: 'second')
      expect(stream.messages.size).to eq(2)
      expect(stream.messages[0][:content]).to eq('first')
      expect(stream.messages[1][:content]).to eq('second')
    end
  end

  describe '#append_streaming' do
    before { stream.add_message(role: :assistant, content: 'Hello') }

    it 'appends text to last message content' do
      stream.append_streaming(' world')
      expect(stream.messages.last[:content]).to eq('Hello world')
    end

    it 'can append multiple times' do
      stream.append_streaming(' world')
      stream.append_streaming('!')
      expect(stream.messages.last[:content]).to eq('Hello world!')
    end

    it 'does not modify other messages' do
      stream.add_message(role: :user, content: 'User msg')
      stream.append_streaming(' appended')
      expect(stream.messages.first[:content]).to eq('Hello')
    end
  end

  describe '#add_tool_panel' do
    before { stream.add_message(role: :assistant, content: 'Using a tool') }

    it 'attaches the panel to the last message' do
      panel = double('panel')
      stream.add_tool_panel(panel)
      expect(stream.messages.last[:tool_panels]).to include(panel)
    end

    it 'can attach multiple panels' do
      panel1 = double('panel1')
      panel2 = double('panel2')
      stream.add_tool_panel(panel1)
      stream.add_tool_panel(panel2)
      expect(stream.messages.last[:tool_panels].size).to eq(2)
    end
  end

  describe '#scroll_up' do
    it 'increases scroll_offset by 1 by default' do
      stream.scroll_up
      expect(stream.scroll_offset).to eq(1)
    end

    it 'increases scroll_offset by given lines' do
      stream.scroll_up(5)
      expect(stream.scroll_offset).to eq(5)
    end
  end

  describe '#scroll_down' do
    it 'decreases scroll_offset by 1 by default' do
      stream.scroll_up(3)
      stream.scroll_down
      expect(stream.scroll_offset).to eq(2)
    end

    it 'clamps to 0 and does not go negative' do
      stream.scroll_down(10)
      expect(stream.scroll_offset).to eq(0)
    end

    it 'clamps to 0 when decrement exceeds offset' do
      stream.scroll_up(2)
      stream.scroll_down(5)
      expect(stream.scroll_offset).to eq(0)
    end
  end

  describe '#render' do
    it 'returns an array of strings' do
      stream.add_message(role: :user, content: 'Hello')
      result = stream.render(width: 80, height: 20)
      expect(result).to be_an(Array)
      expect(result).to all(be_a(String))
    end

    it 'returns array when no messages' do
      result = stream.render(width: 80, height: 20)
      expect(result).to be_an(Array)
    end

    it 'respects height viewport by returning at most height lines' do
      10.times { |i| stream.add_message(role: :user, content: "Message #{i}") }
      result = stream.render(width: 80, height: 5)
      expect(result.size).to be <= 5
    end

    it 'renders user messages' do
      stream.add_message(role: :user, content: 'Hello there')
      result = stream.render(width: 80, height: 20)
      joined = result.join("\n")
      expect(joined).to include('Hello there')
    end

    it 'renders assistant messages' do
      stream.add_message(role: :assistant, content: 'I can help')
      result = stream.render(width: 80, height: 20)
      joined = result.join("\n")
      expect(joined).to include('I can help')
    end

    it 'renders system messages' do
      stream.add_message(role: :system, content: 'System notice')
      result = stream.render(width: 80, height: 20)
      joined = result.join("\n")
      expect(joined).to include('System notice')
    end

    it 'renders tool panel output' do
      stream.add_message(role: :assistant, content: 'Using tool')
      panel = double('panel')
      allow(panel).to receive(:render).with(width: 80).and_return("tool output\nline2")
      stream.add_tool_panel(panel)
      result = stream.render(width: 80, height: 20)
      joined = result.join("\n")
      expect(joined).to include('tool output')
    end

    it 'renders assistant message with markdown content without error' do
      stream.add_message(role: :assistant, content: '**bold** and _italic_ text')
      expect { stream.render(width: 80, height: 20) }.not_to raise_error
      result = stream.render(width: 80, height: 20)
      expect(result).to be_an(Array)
    end
  end

  describe '#render_markdown (via assistant rendering)' do
    it 'falls back to plain text if MarkdownView raises' do
      stream.add_message(role: :assistant, content: 'plain text fallback')
      allow(Legion::TTY::Components::MarkdownView).to receive(:render).and_raise(StandardError, 'render failed')
      result = stream.render(width: 80, height: 20)
      joined = result.join("\n")
      expect(joined).to include('plain text fallback')
    end
  end
end
