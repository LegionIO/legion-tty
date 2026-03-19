# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/freq command' do
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
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(false)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe '/freq' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/freq')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :user, content: 'hello world hello')
      expect(chat.handle_slash_command('/freq')).to eq(:handled)
    end

    it 'shows "No words to analyse." when conversation has no usable words' do
      # Only stop words / single-character words
      chat.message_stream.messages.clear
      chat.handle_slash_command('/freq')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No words to analyse.')
    end

    it 'shows the top word in frequency output' do
      chat.message_stream.add_message(role: :user, content: 'hello hello hello world')
      chat.handle_slash_command('/freq')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('hello')
    end

    it 'excludes stop words from the frequency table' do
      chat.message_stream.add_message(role: :user, content: 'the the the engine runs')
      chat.handle_slash_command('/freq')
      content = chat.message_stream.messages.last[:content]
      # 'the' is a stop word and must not appear as a counted word
      lines = content.split("\n").reject { |l| l.include?('Word frequency') || l.strip.start_with?('#') }
      expect(lines.none? { |l| l.match?(/\bthe\b/) }).to be true
    end

    it 'includes a percentage column in the output' do
      chat.message_stream.add_message(role: :user, content: 'engine engine engine compute')
      chat.handle_slash_command('/freq')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/%/)
    end

    it 'shows at most 20 rows' do
      # Generate 30 unique words
      words = (1..30).map { |n| "word#{n}" }.join(' ')
      chat.message_stream.add_message(role: :user, content: words)
      chat.handle_slash_command('/freq')
      content = chat.message_stream.messages.last[:content]
      # Count numbered rank lines (e.g. "   1.")
      rank_lines = content.split("\n").grep(/\s+\d+\./)
      expect(rank_lines.size).to be <= 20
    end
  end
end
