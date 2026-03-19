# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/log and /version commands' do
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
  # /log
  # ---------------------------------------------------------------------------
  describe '/log' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/log')
    end

    it 'returns :handled' do
      allow(chat).to receive(:handle_log).and_return(:handled)
      result = chat.handle_slash_command('/log')
      expect(result).to eq(:handled)
    end

    context 'when the boot log does not exist' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.expand_path('~/.legionio/logs/tty-boot.log')).and_return(false)
      end

      it 'reports "No boot log found."' do
        chat.handle_slash_command('/log')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No boot log found.')
      end
    end

    context 'when the boot log exists' do
      let(:tmp_log) { Tempfile.new(['tty-boot', '.log']) }

      before do
        lines = (1..30).map { |i| "Log line #{i}" }
        tmp_log.write(lines.join("\n"))
        tmp_log.flush
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.expand_path('~/.legionio/logs/tty-boot.log')).and_return(true)
        allow(File).to receive(:readlines).and_call_original
        allow(File).to receive(:readlines)
          .with(File.expand_path('~/.legionio/logs/tty-boot.log'), chomp: true)
          .and_return(lines)
      end

      after { tmp_log.unlink }

      it 'shows the last 20 lines by default' do
        chat.handle_slash_command('/log')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Log line 30')
        expect(content).to include('Log line 11')
        expect(content).not_to include('Log line 10 ')
      end

      it 'shows "Boot log (last N lines):" header' do
        chat.handle_slash_command('/log')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to match(/Boot log \(last \d+ lines\):/)
      end

      it 'shows last N lines when N is specified' do
        chat.handle_slash_command('/log 5')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Log line 30')
        expect(content).to include('Log line 26')
      end

      it 'clamps N to at least 1' do
        chat.handle_slash_command('/log 0')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('last 1 lines')
      end

      it 'clamps N to at most 500' do
        chat.handle_slash_command('/log 9999')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('last 30 lines')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # /version
  # ---------------------------------------------------------------------------
  describe '/version' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/version')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/version')
      expect(result).to eq(:handled)
    end

    it 'shows legion-tty version' do
      chat.handle_slash_command('/version')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include("legion-tty v#{Legion::TTY::VERSION}")
    end

    it 'shows the Ruby version' do
      chat.handle_slash_command('/version')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include("Ruby: #{RUBY_VERSION}")
    end

    it 'shows the platform' do
      chat.handle_slash_command('/version')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include("Platform: #{RUBY_PLATFORM}")
    end

    it 'version string matches VERSION constant' do
      chat.handle_slash_command('/version')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include(Legion::TTY::VERSION)
    end

    it 'shows version info as a system message' do
      chat.handle_slash_command('/version')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last).not_to be_nil
    end
  end
end
