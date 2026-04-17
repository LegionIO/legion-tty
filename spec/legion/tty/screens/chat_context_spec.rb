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

    context 'when Legion::LLM::Skills::Registry is defined with auto-inject skills' do
      before do
        registry = Module.new do
          def self.by_trigger(_trigger) = []
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
        skill = double(namespace: 'disk', skill_name: 'my-skill')
        allow(Legion::LLM::Skills::Registry).to receive(:by_trigger).with(:auto_inject).and_return([skill])
      end

      it 'appends auto-inject skill names to context output' do
        chat.handle_slash_command('/context')
        content = chat.message_stream.messages.last[:content]
        expect(content).to include('Auto-inject Skills')
        expect(content).to include('disk:my-skill')
      end

      it 'shows the skill count in the auto-inject header' do
        chat.handle_slash_command('/context')
        content = chat.message_stream.messages.last[:content]
        expect(content).to match(/Auto-inject Skills \(1\)/)
      end
    end

    context 'when Legion::LLM::Skills::Registry is defined but no auto-inject skills' do
      before do
        registry = Module.new do
          def self.by_trigger(_trigger) = []
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
        allow(Legion::LLM::Skills::Registry).to receive(:by_trigger).with(:auto_inject).and_return([])
      end

      it 'does not append auto-inject section' do
        chat.handle_slash_command('/context')
        content = chat.message_stream.messages.last[:content]
        expect(content).not_to include('Auto-inject Skills')
      end
    end
  end
end
