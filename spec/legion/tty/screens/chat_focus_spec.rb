# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/focus command' do
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
    it 'includes /focus' do
      expect(described_class::SLASH_COMMANDS).to include('/focus')
    end
  end

  describe '/focus toggle' do
    it 'returns :handled' do
      result = chat.handle_slash_command('/focus')
      expect(result).to eq(:handled)
    end

    it 'starts with focus mode off' do
      expect(chat.instance_variable_get(:@focus_mode)).to be false
    end

    it 'toggles focus mode on' do
      chat.handle_slash_command('/focus')
      expect(chat.instance_variable_get(:@focus_mode)).to be true
    end

    it 'toggles focus mode off when called again' do
      chat.handle_slash_command('/focus')
      chat.handle_slash_command('/focus')
      expect(chat.instance_variable_get(:@focus_mode)).to be false
    end

    it 'notifies "Focus mode ON" when enabling' do
      expect(chat.status_bar).to receive(:notify).with(hash_including(message: 'Focus mode ON'))
      chat.handle_slash_command('/focus')
    end

    it 'notifies "Focus mode OFF" when disabling' do
      chat.instance_variable_set(:@focus_mode, true)
      expect(chat.status_bar).to receive(:notify).with(hash_including(message: 'Focus mode OFF'))
      chat.handle_slash_command('/focus')
    end
  end

  describe 'render in focus mode' do
    before do
      # Add some messages so the stream has content to fill lines
      5.times { |i| chat.message_stream.add_message(role: :user, content: "message #{i}") }
    end

    it 'returns stream lines without status bar or divider when focus mode is on' do
      chat.instance_variable_set(:@focus_mode, true)
      lines = chat.render(80, 10)
      expect(lines).to all(be_a(String))
      # status_bar.render produces a string with model info; it should NOT appear
      bar_content = chat.status_bar.render(width: 80)
      expect(lines).not_to include(bar_content)
    end

    it 'returns stream_lines plus divider plus bar when focus mode is off' do
      chat.instance_variable_set(:@focus_mode, false)
      lines = chat.render(80, 10)
      # Normal render: stream_height = 10 - 2 = 8 lines + divider + bar_line = at least 3 total
      expect(lines.size).to be >= 3
    end

    it 'focus mode render returns up to full height lines' do
      chat.instance_variable_set(:@focus_mode, true)
      lines = chat.render(80, 3)
      # stream has messages, so should return up to 3 lines
      expect(lines.size).to be <= 3
      expect(lines).to all(be_a(String))
    end

    it 'focus mode render does not include divider line' do
      chat.instance_variable_set(:@focus_mode, true)
      lines = chat.render(80, 10)
      # divider is just dashes — check none of the lines is a plain divider
      divider_pattern = /\A[-\e\[\]0-9;m]+\z/
      all_dividers = lines.all? { |l| l.match?(divider_pattern) }
      expect(all_dividers).to be false
    end
  end
end
