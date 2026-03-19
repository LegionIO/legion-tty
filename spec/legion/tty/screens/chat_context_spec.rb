# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/context command' do
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

  describe '/context' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/context')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/context')).to eq(:handled)
    end

    it 'shows "Session Context:" heading' do
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Session Context:')
    end

    it 'shows personality' do
      chat.instance_variable_set(:@personality, 'friendly')
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('friendly')
    end

    it 'shows "default" when no personality is set' do
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('default')
    end

    it 'shows plan mode status as "on" when enabled' do
      chat.instance_variable_set(:@plan_mode, true)
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('on')
    end

    it 'shows plan mode status as "off" when disabled' do
      chat.instance_variable_set(:@plan_mode, false)
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('off')
    end

    it 'shows session name' do
      chat.instance_variable_set(:@session_name, 'my-session')
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('my-session')
    end

    it 'shows message count' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/Messages\s*:\s*\d+/)
    end

    it 'shows pinned message count' do
      chat.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'pinned' }])
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Pinned')
      expect(content).to include('1')
    end

    it 'shows token summary' do
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Tokens')
    end

    it 'shows model info from provider config when no llm_chat' do
      chat.handle_slash_command('/context')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Model/Provider')
    end

    it 'is mentioned in /help text' do
      overlay_text = nil
      allow(app.screen_manager).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('/context')
    end
  end
end
