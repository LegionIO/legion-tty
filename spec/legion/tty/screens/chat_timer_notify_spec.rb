# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/timer and /notify commands' do
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

  # ---------------------------------------------------------------------------
  # /timer
  # ---------------------------------------------------------------------------
  describe '/timer' do
    after { chat.handle_slash_command('/timer cancel') }

    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/timer')
    end

    it 'returns :handled when setting a timer' do
      expect(chat.handle_slash_command('/timer 5 Test done')).to eq(:handled)
    end

    it 'adds a system message confirming timer is set' do
      chat.handle_slash_command('/timer 10 Take a break')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Timer set for 10s')
      expect(content).to include('Take a break')
    end

    it 'uses default message when none is supplied' do
      chat.handle_slash_command('/timer 10')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Timer set for 10s')
      expect(content).to include('Timer expired!')
    end

    it 'shows status message when called with no args and no timer is running' do
      chat.handle_slash_command('/timer')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No active timer')
    end

    it 'shows remaining time when timer is running' do
      chat.handle_slash_command('/timer 120 Long task')
      chat.handle_slash_command('/timer')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/Timer running:.*remaining/)
    end

    it 'rejects non-numeric seconds and shows usage' do
      chat.handle_slash_command('/timer abc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'cancels an active timer with /timer cancel' do
      chat.handle_slash_command('/timer 60 Cancel me')
      result = chat.handle_slash_command('/timer cancel')
      expect(result).to eq(:handled)
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('cancelled')
    end

    it 'reports no timer to cancel when none is active' do
      chat.handle_slash_command('/timer cancel')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No active timer to cancel')
    end

    it 'blocks starting a second timer while one is running' do
      chat.handle_slash_command('/timer 60 First')
      chat.handle_slash_command('/timer 60 Second')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('already running')
    end

    it 'fires the notification message when timer expires' do
      notifications = []
      allow(chat.status_bar).to receive(:notify) { |**kwargs| notifications << kwargs }
      chat.handle_slash_command('/timer 0 Done!')
      sleep(0.05)
      messages = chat.message_stream.messages.select { |m| m[:role] == :system }
      fired = messages.any? { |m| m[:content].include?('Done!') }
      expect(fired).to be true
    end

    it 'initializes @timer_thread to nil' do
      expect(chat.instance_variable_get(:@timer_thread)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # /notify
  # ---------------------------------------------------------------------------
  describe '/notify' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/notify')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/notify Remember to commit!')).to eq(:handled)
    end

    it 'calls status_bar.notify with the given message' do
      expect(chat.status_bar).to receive(:notify).with(message: 'Remember to commit!', level: :info, ttl: 5)
      chat.handle_slash_command('/notify Remember to commit!')
    end

    it 'passes multi-word messages intact' do
      expect(chat.status_bar).to receive(:notify).with(message: 'Take a short break now', level: :info, ttl: 5)
      chat.handle_slash_command('/notify Take a short break now')
    end

    it 'shows usage when called with no message' do
      chat.handle_slash_command('/notify')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows usage when called with only whitespace' do
      chat.handle_slash_command('/notify   ')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end
end
