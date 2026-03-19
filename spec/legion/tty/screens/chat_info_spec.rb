# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/info command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude', name: 'Jane' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil,
                                                 dismiss_overlay: nil, show_overlay: nil),
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

  describe 'SLASH_COMMANDS' do
    it 'includes /info' do
      expect(described_class::SLASH_COMMANDS).to include('/info')
    end
  end

  describe '/info' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/info')
      expect(result).to eq(:handled)
    end

    it 'shows session name' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Session:')
    end

    it 'shows uptime' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Uptime:')
    end

    it 'shows start time' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Started:')
    end

    it 'shows total message count' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'world')
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Messages:')
    end

    it 'shows message breakdown by role' do
      chat.message_stream.add_message(role: :user, content: 'user message')
      chat.message_stream.add_message(role: :assistant, content: 'assistant reply')
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include('User:')
      expect(content).to include('Assistant:')
      expect(content).to include('System:')
    end

    it 'shows total characters' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Total characters:')
    end

    it 'shows average message length' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Avg message length:')
    end

    it 'shows pinned count' do
      chat.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'pinned' }])
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Pinned:')
    end

    it 'shows aliases count' do
      chat.instance_variable_set(:@aliases, { '/s' => '/save' })
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Aliases:')
    end

    it 'shows snippets count' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Snippets:')
    end

    it 'shows macros count' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Macros:')
    end

    it 'shows autosave status' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Autosave:')
    end

    it 'shows autosave OFF by default' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Autosave: OFF')
    end

    it 'shows autosave ON when enabled' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Autosave: ON')
    end

    it 'shows focus mode state' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Focus mode:')
    end

    it 'shows plan mode state' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Plan mode:')
    end

    it 'shows debug mode state' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Debug mode:')
    end

    it 'shows LLM provider' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('LLM:')
    end

    it 'shows muted system state' do
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Muted system:')
    end

    it 'reflects correct alias count' do
      chat.instance_variable_set(:@aliases, { '/a' => '/alias', '/b' => '/bookmark' })
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Aliases: 2')
    end

    it 'reflects correct pinned count' do
      chat.instance_variable_set(:@pinned_messages, [{}, {}])
      chat.handle_slash_command('/info')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Pinned: 2')
    end
  end
end
