# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/ls and /pwd commands' do
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
  # SLASH_COMMANDS membership
  # ---------------------------------------------------------------------------
  describe 'SLASH_COMMANDS' do
    it 'includes /ls' do
      expect(described_class::SLASH_COMMANDS).to include('/ls')
    end

    it 'includes /pwd' do
      expect(described_class::SLASH_COMMANDS).to include('/pwd')
    end
  end

  # ---------------------------------------------------------------------------
  # /ls
  # ---------------------------------------------------------------------------
  describe '/ls' do
    it 'returns :handled with no args' do
      expect(chat.handle_slash_command('/ls')).to eq(:handled)
    end

    it 'shows entries for the current directory' do
      chat.handle_slash_command('/ls')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include(Dir.pwd)
    end

    it 'appends / suffix to directory entries' do
      chat.handle_slash_command('/ls')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(%r{/})
    end

    it 'accepts an explicit path argument' do
      chat.handle_slash_command("/ls #{Dir.pwd}")
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include(Dir.pwd)
    end

    it 'does not include . or .. in the listing' do
      chat.handle_slash_command('/ls')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      lines = content.split("\n").drop(1)
      expect(lines).not_to include('.')
      expect(lines).not_to include('..')
    end

    it 'returns :handled for a nonexistent path' do
      expect(chat.handle_slash_command('/ls /nonexistent_path_xyz_abc_123')).to eq(:handled)
    end

    it 'shows an error message for a nonexistent path' do
      chat.handle_slash_command('/ls /nonexistent_path_xyz_abc_123')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/ls:/)
    end
  end

  # ---------------------------------------------------------------------------
  # /pwd
  # ---------------------------------------------------------------------------
  describe '/pwd' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/pwd')).to eq(:handled)
    end

    it 'shows the current working directory' do
      chat.handle_slash_command('/pwd')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to eq(Dir.pwd)
    end

    it 'output matches Dir.pwd' do
      expected = Dir.pwd
      chat.handle_slash_command('/pwd')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to eq(expected)
    end

    it 'posts as a system message' do
      chat.handle_slash_command('/pwd')
      last_msg = chat.message_stream.messages.last
      expect(last_msg[:role]).to eq(:system)
    end
  end
end
