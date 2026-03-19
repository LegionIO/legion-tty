# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/about and /commands commands' do
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
  # /about
  # ---------------------------------------------------------------------------
  describe '/about' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/about')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/about')
      expect(result).to eq(:handled)
    end

    it 'shows the gem name' do
      chat.handle_slash_command('/about')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('legion-tty')
    end

    it 'shows the current version' do
      chat.handle_slash_command('/about')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include(Legion::TTY::VERSION)
    end

    it 'shows the author' do
      chat.handle_slash_command('/about')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('Matthew Iverson')
    end

    it 'shows the license' do
      chat.handle_slash_command('/about')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('Apache-2.0')
    end

    it 'shows the GitHub URL' do
      chat.handle_slash_command('/about')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('https://github.com/LegionIO/legion-tty')
    end

    it 'shows the description' do
      chat.handle_slash_command('/about')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('LegionIO async cognition engine')
    end
  end

  # ---------------------------------------------------------------------------
  # /commands
  # ---------------------------------------------------------------------------
  describe '/commands' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/commands')
    end

    it 'returns :handled with no argument' do
      result = chat.handle_slash_command('/commands')
      expect(result).to eq(:handled)
    end

    it 'lists all commands when no pattern is given' do
      chat.handle_slash_command('/commands')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('/help')
      expect(content).to include('/quit')
      expect(content).to include('/about')
      expect(content).to include('/commands')
    end

    it 'shows total count in header with no pattern' do
      chat.handle_slash_command('/commands')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      total = described_class::SLASH_COMMANDS.size
      expect(content).to include("All commands (#{total}):")
    end

    it 'filters commands by pattern (case-insensitive)' do
      chat.handle_slash_command('/commands save')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('/save')
      expect(content).to include('/autosave')
    end

    it 'shows matching count in header when pattern given' do
      chat.handle_slash_command('/commands model')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Commands matching 'model' \(\d+\):/)
    end

    it 'excludes non-matching commands when pattern is given' do
      chat.handle_slash_command('/commands zzznomatch')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include("Commands matching 'zzznomatch' (0):")
    end

    it 'returns :handled with a pattern argument' do
      result = chat.handle_slash_command('/commands help')
      expect(result).to eq(:handled)
    end
  end
end
