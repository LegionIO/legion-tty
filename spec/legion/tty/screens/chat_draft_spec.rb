# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/draft command' do
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
    it 'includes /draft' do
      expect(described_class::SLASH_COMMANDS).to include('/draft')
    end
  end

  describe 'initialize' do
    it 'sets @draft to nil' do
      expect(chat.instance_variable_get(:@draft)).to be_nil
    end
  end

  describe '/draft <text>' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/draft Hello world')).to eq(:handled)
    end

    it 'saves the text to @draft' do
      chat.handle_slash_command('/draft Hello world')
      expect(chat.instance_variable_get(:@draft)).to eq('Hello world')
    end

    it 'shows a confirmation message' do
      chat.handle_slash_command('/draft Hello world')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Draft saved')
      expect(content).to include('Hello world')
    end

    it 'overwrites a previous draft' do
      chat.handle_slash_command('/draft first draft')
      chat.handle_slash_command('/draft second draft')
      expect(chat.instance_variable_get(:@draft)).to eq('second draft')
    end
  end

  describe '/draft (no argument)' do
    it 'shows "No draft saved." when no draft exists' do
      chat.handle_slash_command('/draft')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No draft saved.')
    end

    it 'shows the current draft when one is saved' do
      chat.instance_variable_set(:@draft, 'my pending text')
      chat.handle_slash_command('/draft')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('my pending text')
    end
  end

  describe '/draft clear' do
    it 'clears the draft' do
      chat.instance_variable_set(:@draft, 'some text')
      chat.handle_slash_command('/draft clear')
      expect(chat.instance_variable_get(:@draft)).to be_nil
    end

    it 'shows a confirmation' do
      chat.handle_slash_command('/draft clear')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('cleared')
    end
  end

  describe '/draft send' do
    it 'shows error when no draft is saved' do
      chat.handle_slash_command('/draft send')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No draft to send.')
    end

    it 'dispatches the draft as a user message' do
      chat.instance_variable_set(:@draft, 'my draft text')
      expect(chat).to receive(:handle_user_message).with('my draft text')
      chat.handle_slash_command('/draft send')
    end

    it 'clears @draft after sending' do
      chat.instance_variable_set(:@draft, 'my draft text')
      allow(chat).to receive(:handle_user_message)
      chat.handle_slash_command('/draft send')
      expect(chat.instance_variable_get(:@draft)).to be_nil
    end
  end
end
