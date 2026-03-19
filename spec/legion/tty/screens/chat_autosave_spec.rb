# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/autosave command' do
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

  describe '/autosave' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/autosave')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/autosave')).to eq(:handled)
    end

    it 'starts disabled by default' do
      expect(chat.instance_variable_get(:@autosave_enabled)).to be false
    end

    it 'toggles autosave ON when called with no args and currently off' do
      chat.handle_slash_command('/autosave')
      expect(chat.instance_variable_get(:@autosave_enabled)).to be true
    end

    it 'toggles autosave OFF when called with no args and currently on' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.handle_slash_command('/autosave')
      expect(chat.instance_variable_get(:@autosave_enabled)).to be false
    end

    it 'shows ON status message when enabling' do
      chat.handle_slash_command('/autosave')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('ON')
    end

    it 'shows OFF status message when disabling' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.handle_slash_command('/autosave')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('OFF')
    end

    it 'sets interval and enables when given a number' do
      chat.handle_slash_command('/autosave 30')
      expect(chat.instance_variable_get(:@autosave_interval)).to eq(30)
      expect(chat.instance_variable_get(:@autosave_enabled)).to be true
    end

    it 'shows interval in confirmation message when given a number' do
      chat.handle_slash_command('/autosave 30')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('30')
    end

    it 'disables autosave when given "off"' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.handle_slash_command('/autosave off')
      expect(chat.instance_variable_get(:@autosave_enabled)).to be false
    end

    it 'shows OFF message when given "off"' do
      chat.handle_slash_command('/autosave off')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('OFF')
    end

    it 'shows usage for unrecognised argument' do
      chat.handle_slash_command('/autosave bogus')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'notifies status bar on toggle' do
      expect(chat.status_bar).to receive(:notify).with(hash_including(level: :info))
      chat.handle_slash_command('/autosave')
    end

    it 'has default interval of 60 seconds' do
      expect(chat.instance_variable_get(:@autosave_interval)).to eq(60)
    end
  end

  describe '#check_autosave' do
    let(:session_store) { instance_double(Legion::TTY::SessionStore, save: nil, auto_session_name: 'auto-session') }

    before do
      chat.instance_variable_set(:@session_store, session_store)
    end

    it 'does nothing when autosave is disabled' do
      chat.instance_variable_set(:@autosave_enabled, false)
      chat.message_stream.add_message(role: :user, content: 'hello')
      expect(session_store).not_to receive(:save)
      chat.send(:check_autosave)
    end

    it 'does nothing when interval has not elapsed' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.instance_variable_set(:@autosave_interval, 60)
      chat.instance_variable_set(:@last_autosave, Time.now)
      chat.message_stream.add_message(role: :user, content: 'hello')
      expect(session_store).not_to receive(:save)
      chat.send(:check_autosave)
    end

    it 'saves when autosave is enabled and interval has elapsed' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.instance_variable_set(:@autosave_interval, 60)
      chat.instance_variable_set(:@last_autosave, Time.now - 120)
      chat.instance_variable_set(:@session_name, 'my-session')
      chat.message_stream.add_message(role: :user, content: 'hello')
      expect(session_store).to receive(:save).with('my-session', messages: anything)
      chat.send(:check_autosave)
    end

    it 'updates @last_autosave after saving' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.instance_variable_set(:@autosave_interval, 60)
      old_time = Time.now - 120
      chat.instance_variable_set(:@last_autosave, old_time)
      chat.instance_variable_set(:@session_name, 'my-session')
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.send(:check_autosave)
      expect(chat.instance_variable_get(:@last_autosave)).not_to eq(old_time)
    end

    it 'notifies status bar after autosave' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.instance_variable_set(:@autosave_interval, 60)
      chat.instance_variable_set(:@last_autosave, Time.now - 120)
      chat.instance_variable_set(:@session_name, 'my-session')
      chat.message_stream.add_message(role: :user, content: 'hello')
      expect(chat.status_bar).to receive(:notify).with(hash_including(message: 'Autosaved'))
      chat.send(:check_autosave)
    end
  end
end
