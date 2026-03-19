# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/calc command' do
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

  describe '/calc' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/calc')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/calc 2 + 2')).to eq(:handled)
    end

    it 'evaluates basic addition' do
      chat.handle_slash_command('/calc 2 + 2')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('= 4')
    end

    it 'evaluates float division' do
      chat.handle_slash_command('/calc 100 / 3.0')
      content = chat.message_stream.messages.last[:content]
      expect(content).to start_with('= 33.3')
    end

    it 'evaluates exponentiation' do
      chat.handle_slash_command('/calc 2**10')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('= 1024')
    end

    it 'evaluates Math.sqrt' do
      chat.handle_slash_command('/calc Math.sqrt(144)')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('= 12.0')
    end

    it 'evaluates modulo' do
      chat.handle_slash_command('/calc 17 % 5')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('= 2')
    end

    it 'evaluates parenthesized expressions' do
      chat.handle_slash_command('/calc (2 + 3) * 4')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('= 20')
    end

    it 'shows usage when no expression given' do
      chat.handle_slash_command('/calc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'blocks dangerous expressions with system call patterns' do
      chat.handle_slash_command('/calc `ls`')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('blocked').or include('Usage:').or include('Error:')
      expect(content).not_to match(/\A= /)
    end

    it 'blocks expressions containing letters that are not Math functions' do
      chat.handle_slash_command('/calc system("ls")')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('blocked').or include('Usage:').or include('Error:')
      expect(content).not_to match(/\A= /)
    end
  end
end
