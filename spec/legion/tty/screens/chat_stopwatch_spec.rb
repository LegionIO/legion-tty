# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/stopwatch command' do
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

  describe '/stopwatch' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/stopwatch')
    end

    it 'returns :handled for start' do
      expect(chat.handle_slash_command('/stopwatch start')).to eq(:handled)
    end

    it 'returns :handled for stop' do
      chat.handle_slash_command('/stopwatch start')
      expect(chat.handle_slash_command('/stopwatch stop')).to eq(:handled)
    end

    it 'returns :handled for lap' do
      expect(chat.handle_slash_command('/stopwatch lap')).to eq(:handled)
    end

    it 'returns :handled for reset' do
      expect(chat.handle_slash_command('/stopwatch reset')).to eq(:handled)
    end

    it 'returns :handled with no subcommand' do
      expect(chat.handle_slash_command('/stopwatch')).to eq(:handled)
    end

    it 'shows "not started" status when stopwatch has never been used' do
      chat.handle_slash_command('/stopwatch')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not started')
    end

    it 'shows "started" message after /stopwatch start' do
      chat.handle_slash_command('/stopwatch start')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('started')
    end

    it 'shows elapsed time after stop' do
      chat.handle_slash_command('/stopwatch start')
      chat.handle_slash_command('/stopwatch stop')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/\d{2}:\d{2}\.\d{3}/)
    end

    it 'shows "not running" when stopping a stopwatch that was never started' do
      chat.handle_slash_command('/stopwatch stop')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not running')
    end

    it 'shows lap time in MM:SS.ms format' do
      chat.handle_slash_command('/stopwatch start')
      chat.handle_slash_command('/stopwatch lap')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/Lap:.*\d{2}:\d{2}\.\d{3}/)
    end

    it 'shows "reset" message after /stopwatch reset' do
      chat.handle_slash_command('/stopwatch start')
      chat.handle_slash_command('/stopwatch reset')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('reset')
    end

    it 'resets elapsed to zero after reset' do
      chat.handle_slash_command('/stopwatch start')
      chat.handle_slash_command('/stopwatch stop')
      chat.handle_slash_command('/stopwatch reset')
      chat.handle_slash_command('/stopwatch')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not started')
    end

    it 'shows "running" status while stopwatch is active' do
      chat.handle_slash_command('/stopwatch start')
      chat.handle_slash_command('/stopwatch')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('running')
    end

    it 'shows "stopped at" status after stop' do
      chat.handle_slash_command('/stopwatch start')
      chat.handle_slash_command('/stopwatch stop')
      chat.handle_slash_command('/stopwatch')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('stopped at')
    end

    it 'formats zero elapsed as 00:00.000' do
      chat.handle_slash_command('/stopwatch')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('00:00.000')
    end
  end
end
