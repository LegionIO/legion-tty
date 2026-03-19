# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/silent command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
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
    it 'includes /silent' do
      expect(described_class::SLASH_COMMANDS).to include('/silent')
    end
  end

  describe '/silent initialization' do
    it 'starts with silent_mode false' do
      expect(chat.instance_variable_get(:@silent_mode)).to be false
    end
  end

  describe '/silent toggle' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/silent')).to eq(:handled)
    end

    it 'toggles silent_mode to true on first call' do
      chat.handle_slash_command('/silent')
      expect(chat.instance_variable_get(:@silent_mode)).to be true
    end

    it 'toggles silent_mode back to false on second call' do
      chat.handle_slash_command('/silent')
      chat.handle_slash_command('/silent')
      expect(chat.instance_variable_get(:@silent_mode)).to be false
    end

    it 'shows "Silent mode ON" when enabling' do
      chat.handle_slash_command('/silent')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Silent mode ON')
    end

    it 'shows "Silent mode OFF" when disabling' do
      chat.handle_slash_command('/silent')
      chat.handle_slash_command('/silent')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Silent mode OFF')
    end

    it 'propagates silent_mode to message_stream' do
      chat.handle_slash_command('/silent')
      expect(chat.message_stream.silent_mode).to be true
    end

    it 'calls status_bar.update with silent: true when enabling' do
      expect(chat.status_bar).to receive(:update).with(hash_including(silent: true))
      chat.handle_slash_command('/silent')
    end

    it 'calls status_bar.update with silent: false when disabling' do
      chat.instance_variable_set(:@silent_mode, true)
      expect(chat.status_bar).to receive(:update).with(hash_including(silent: false))
      chat.handle_slash_command('/silent')
    end
  end

  describe 'MessageStream silent_mode filtering' do
    it 'message_stream initializes with silent_mode false' do
      expect(chat.message_stream.silent_mode).to be false
    end

    it 'hides assistant messages when silent_mode is true' do
      chat.message_stream.add_message(role: :assistant, content: 'hidden response')
      chat.message_stream.silent_mode = true
      lines = chat.message_stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      expect(combined).not_to include('hidden response')
    end

    it 'shows assistant messages when silent_mode is false' do
      chat.message_stream.add_message(role: :assistant, content: 'visible response')
      chat.message_stream.silent_mode = false
      lines = chat.message_stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      expect(combined).to include('visible response')
    end

    it 'still shows user messages when silent_mode is true' do
      chat.message_stream.add_message(role: :user, content: 'user question')
      chat.message_stream.add_message(role: :assistant, content: 'assistant answer')
      chat.message_stream.silent_mode = true
      lines = chat.message_stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      expect(combined).to include('user question')
    end
  end

  describe 'StatusBar [SILENT] indicator' do
    it 'shows [SILENT] when silent is true' do
      chat.status_bar.update(silent: true)
      expect(chat.status_bar.render(width: 200)).to include('[SILENT]')
    end

    it 'does not show [SILENT] when silent is false' do
      chat.status_bar.update(silent: false)
      expect(chat.status_bar.render(width: 200)).not_to include('[SILENT]')
    end

    it 'does not show [SILENT] by default' do
      expect(chat.status_bar.render(width: 200)).not_to include('[SILENT]')
    end
  end
end
