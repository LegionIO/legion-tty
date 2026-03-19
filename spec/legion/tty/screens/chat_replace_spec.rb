# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/replace command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil,
                                                 show_overlay: nil),
                    hotkeys: double('hk', list: []),
                    respond_to?: true)
  end

  before do
    allow(reader).to receive(:on)
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe '/replace' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/replace')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/replace foo >>> bar')).to eq(:handled)
    end

    it 'shows usage when no separator present' do
      chat.handle_slash_command('/replace just some text')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows usage when no args provided' do
      chat.handle_slash_command('/replace')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'replaces matching text in user messages' do
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.handle_slash_command('/replace world >>> earth')
      msg = chat.message_stream.messages.first
      expect(msg[:content]).to eq('hello earth')
    end

    it 'replaces matching text in assistant messages' do
      chat.message_stream.add_message(role: :assistant, content: 'The answer is 42')
      chat.handle_slash_command('/replace 42 >>> forty-two')
      msg = chat.message_stream.messages.first
      expect(msg[:content]).to eq('The answer is forty-two')
    end

    it 'replaces all occurrences across all messages' do
      chat.message_stream.add_message(role: :user, content: 'foo and foo')
      chat.message_stream.add_message(role: :assistant, content: 'foo is great')
      chat.handle_slash_command('/replace foo >>> bar')
      expect(chat.message_stream.messages[0][:content]).to eq('bar and bar')
      expect(chat.message_stream.messages[1][:content]).to eq('bar is great')
    end

    it 'reports total replacement count' do
      chat.message_stream.add_message(role: :user, content: 'foo foo foo')
      chat.handle_slash_command('/replace foo >>> bar')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('3')
      expect(content).to include("'foo'")
      expect(content).to include("'bar'")
    end

    it 'uses singular "occurrence" when count is 1' do
      chat.message_stream.add_message(role: :user, content: 'just once foo here')
      chat.handle_slash_command('/replace foo >>> bar')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/1 occurrence[^s]/)
    end

    it 'uses plural "occurrences" when count is more than 1' do
      chat.message_stream.add_message(role: :user, content: 'foo foo')
      chat.handle_slash_command('/replace foo >>> bar')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('occurrences')
    end

    it 'reports no occurrences found when old_text not in any message' do
      chat.message_stream.add_message(role: :user, content: 'nothing to replace')
      chat.handle_slash_command('/replace xyz >>> abc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("No occurrences of 'xyz'")
    end

    it 'can replace with empty string (deletion)' do
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.handle_slash_command('/replace world >>> ')
      msg = chat.message_stream.messages.first
      expect(msg[:content]).to eq('hello ')
    end

    it 'does not modify non-string message content' do
      panel = double('panel')
      chat.message_stream.messages << { role: :tool, content: panel, tool_panel: true }
      expect { chat.handle_slash_command('/replace foo >>> bar') }.not_to raise_error
    end
  end
end
