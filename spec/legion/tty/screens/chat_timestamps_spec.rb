# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/timestamps command' do
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
    it 'includes /timestamps' do
      expect(described_class::SLASH_COMMANDS).to include('/timestamps')
    end
  end

  describe '/timestamps initialization' do
    it 'message_stream starts with show_timestamps true' do
      expect(chat.message_stream.show_timestamps).to be true
    end
  end

  describe '/timestamps off' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/timestamps off')).to eq(:handled)
    end

    it 'sets show_timestamps to false on message_stream' do
      chat.handle_slash_command('/timestamps off')
      expect(chat.message_stream.show_timestamps).to be false
    end

    it 'shows "Timestamps OFF" confirmation' do
      chat.handle_slash_command('/timestamps off')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Timestamps OFF.')
    end
  end

  describe '/timestamps on' do
    before { chat.message_stream.show_timestamps = false }

    it 'sets show_timestamps to true on message_stream' do
      chat.handle_slash_command('/timestamps on')
      expect(chat.message_stream.show_timestamps).to be true
    end

    it 'shows "Timestamps ON" confirmation' do
      chat.handle_slash_command('/timestamps on')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Timestamps ON.')
    end
  end

  describe '/timestamps (toggle)' do
    it 'toggles show_timestamps from true to false' do
      chat.handle_slash_command('/timestamps')
      expect(chat.message_stream.show_timestamps).to be false
    end

    it 'toggles show_timestamps from false to true' do
      chat.message_stream.show_timestamps = false
      chat.handle_slash_command('/timestamps')
      expect(chat.message_stream.show_timestamps).to be true
    end
  end
end

RSpec.describe Legion::TTY::Components::MessageStream, 'show_timestamps rendering' do
  subject(:stream) { described_class.new }

  describe '#show_timestamps' do
    it 'initializes to true' do
      expect(stream.show_timestamps).to be true
    end

    it 'can be set to false via attr_accessor' do
      stream.show_timestamps = false
      expect(stream.show_timestamps).to be false
    end
  end

  describe 'render without timestamps' do
    before do
      stream.add_message(role: :user, content: 'hello world')
    end

    it 'includes a timestamp pattern when show_timestamps is true' do
      stream.show_timestamps = true
      lines = stream.render(width: 80, height: 20)
      combined = lines.join("\n")
      # Timestamps are formatted as HH:MM — match two-digit hour/minute
      expect(combined).to match(/\d{2}:\d{2}/)
    end

    it 'excludes the HH:MM timestamp when show_timestamps is false' do
      stream.show_timestamps = false
      lines = stream.render(width: 80, height: 20)
      # Strip ANSI to compare plain text
      combined = lines.map { |l| l.gsub(/\e\[[0-9;]*m/, '') }.join("\n")
      expect(combined).not_to match(/\d{2}:\d{2}/)
    end

    it 'still shows message content when show_timestamps is false' do
      stream.show_timestamps = false
      lines = stream.render(width: 80, height: 20)
      combined = lines.map { |l| l.gsub(/\e\[[0-9;]*m/, '') }.join("\n")
      expect(combined).to include('hello world')
    end
  end
end
