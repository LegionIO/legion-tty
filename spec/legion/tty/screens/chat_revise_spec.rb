# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/revise command' do
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
    it 'includes /revise' do
      expect(described_class::SLASH_COMMANDS).to include('/revise')
    end
  end

  describe '/revise <text>' do
    it 'returns :handled' do
      chat.message_stream.add_message(role: :user, content: 'original')
      expect(chat.handle_slash_command('/revise replacement')).to eq(:handled)
    end

    it 'replaces the content of the last user message' do
      chat.message_stream.add_message(role: :user, content: 'original text')
      chat.handle_slash_command('/revise corrected text')
      msg = chat.message_stream.messages.reverse.find { |m| m[:role] == :user }
      expect(msg[:content]).to eq('corrected text')
    end

    it 'shows a confirmation with the new content' do
      chat.message_stream.add_message(role: :user, content: 'original')
      chat.handle_slash_command('/revise new version')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Revised')
      expect(content).to include('new version')
    end

    it 'revises the most recent user message when multiple exist' do
      chat.message_stream.add_message(role: :user, content: 'first')
      chat.message_stream.add_message(role: :user, content: 'second')
      chat.handle_slash_command('/revise updated second')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(msgs.last[:content]).to eq('updated second')
      expect(msgs.first[:content]).to eq('first')
    end

    it 'does not affect assistant messages' do
      chat.message_stream.add_message(role: :user, content: 'user msg')
      chat.message_stream.add_message(role: :assistant, content: 'assistant reply')
      chat.handle_slash_command('/revise revised user msg')
      asst = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(asst[:content]).to eq('assistant reply')
    end
  end

  describe '/revise (no argument)' do
    it 'shows usage when no text provided' do
      chat.handle_slash_command('/revise')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/revise with no user messages' do
    it 'shows an error' do
      chat.handle_slash_command('/revise something')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No user message to revise.')
    end
  end
end
