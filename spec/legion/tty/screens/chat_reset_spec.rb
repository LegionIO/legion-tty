# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/reset command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude', name: 'Tester' },
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

  describe '/reset' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/reset')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/reset')).to eq(:handled)
    end

    it 'clears all messages' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'hi')
      chat.handle_slash_command('/reset')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs).to be_empty
    end

    it 'resets plan_mode to false' do
      chat.instance_variable_set(:@plan_mode, true)
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@plan_mode)).to be false
    end

    it 'resets focus_mode to false' do
      chat.instance_variable_set(:@focus_mode, true)
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@focus_mode)).to be false
    end

    it 'resets debug_mode to false' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@debug_mode)).to be false
    end

    it 'resets muted_system to false' do
      chat.instance_variable_set(:@muted_system, true)
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@muted_system)).to be false
    end

    it 'clears pinned_messages' do
      chat.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'pinned' }])
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@pinned_messages)).to be_empty
    end

    it 'clears aliases' do
      chat.instance_variable_set(:@aliases, { '/h' => '/help' })
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@aliases)).to be_empty
    end

    it 'clears macros' do
      chat.instance_variable_set(:@macros, { 'mymacro' => ['/help'] })
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@macros)).to be_empty
    end

    it 'clears recording state' do
      chat.instance_variable_set(:@recording_macro, 'rec')
      chat.instance_variable_set(:@macro_buffer, ['/help'])
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@recording_macro)).to be_nil
      expect(chat.instance_variable_get(:@macro_buffer)).to be_empty
    end

    it 'resets session_name to default' do
      chat.instance_variable_set(:@session_name, 'work')
      chat.handle_slash_command('/reset')
      expect(chat.instance_variable_get(:@session_name)).to eq('default')
    end

    it 'adds a welcome system message after reset' do
      chat.handle_slash_command('/reset')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Welcome')
    end

    it 'shows a Session reset notification' do
      notified = nil
      allow(chat.status_bar).to receive(:notify) { |**kwargs| notified = kwargs[:message] }
      chat.handle_slash_command('/reset')
      expect(notified).to eq('Session reset')
    end
  end
end
