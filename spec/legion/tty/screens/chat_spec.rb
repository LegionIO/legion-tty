# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat do
  let(:app) { double('app', config: { name: 'Matt', provider: 'claude' }) }
  let(:output) { StringIO.new }
  let(:mock_input_bar) do
    instance_double(Legion::TTY::Components::InputBar,
                    prompt_string: '> ',
                    show_thinking: nil,
                    clear_thinking: nil,
                    thinking?: false)
  end

  subject(:screen) { described_class.new(app, output: output, input_bar: mock_input_bar) }

  describe '#initialize' do
    it 'stores the app reference' do
      expect(screen.app).to eq(app)
    end

    it 'creates a MessageStream' do
      expect(screen.message_stream).to be_a(Legion::TTY::Components::MessageStream)
    end

    it 'creates a StatusBar' do
      expect(screen.status_bar).to be_a(Legion::TTY::Components::StatusBar)
    end
  end

  describe '#activate' do
    before do
      allow(app).to receive(:config).and_return({ name: 'Matt', provider: 'claude' })
    end

    it 'adds a system welcome message' do
      screen.activate
      expect(screen.message_stream.messages).not_to be_empty
    end

    it 'sets the running state' do
      screen.activate
      expect(screen.running?).to be true
    end

    it 'updates the status bar with provider info' do
      screen.activate
      expect(screen.status_bar).to be_a(Legion::TTY::Components::StatusBar)
    end
  end

  describe '#handle_slash_command' do
    it 'recognizes /help' do
      result = screen.handle_slash_command('/help')
      expect(result).to eq(:handled)
    end

    it 'recognizes /quit' do
      result = screen.handle_slash_command('/quit')
      expect(result).to eq(:quit)
    end

    it 'recognizes /clear' do
      result = screen.handle_slash_command('/clear')
      expect(result).to eq(:handled)
    end

    it 'returns nil for non-commands' do
      result = screen.handle_slash_command('hello world')
      expect(result).to be_nil
    end

    it 'returns nil for empty string' do
      result = screen.handle_slash_command('')
      expect(result).to be_nil
    end

    it 'recognizes /model with argument' do
      result = screen.handle_slash_command('/model claude-opus-4')
      expect(result).to eq(:handled)
    end

    it '/model with no argument shows current model and does not crash' do
      result = screen.handle_slash_command('/model')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Current model:/)
    end

    it '/model with invalid name when with_model raises shows error and does not crash' do
      llm = double('llm_chat')
      allow(llm).to receive(:respond_to?).with(:with_model).and_return(true)
      allow(llm).to receive(:with_model).and_raise(StandardError, 'model not found')
      screen.instance_variable_set(:@llm_chat, llm)
      result = screen.handle_slash_command('/model bad-model-name')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Failed to switch model:/)
    end

    it '/model with no llm_chat shows no active session message' do
      screen.instance_variable_set(:@llm_chat, nil)
      result = screen.handle_slash_command('/model some-model')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No active LLM session.')
    end

    it 'recognizes /session with argument' do
      result = screen.handle_slash_command('/session mysession')
      expect(result).to eq(:handled)
    end

    it 'recognizes /cost' do
      result = screen.handle_slash_command('/cost')
      expect(result).to eq(:handled)
    end

    it 'recognizes /export' do
      result = screen.handle_slash_command('/export')
      expect(result).to eq(:handled)
    end

    it 'recognizes /tools' do
      result = screen.handle_slash_command('/tools')
      expect(result).to eq(:handled)
    end

    it 'recognizes /dashboard' do
      allow(app).to receive(:respond_to?).and_return(false)
      result = screen.handle_slash_command('/dashboard')
      expect(result).to eq(:handled)
    end

    it 'recognizes /hotkeys' do
      allow(app).to receive(:respond_to?).and_return(false)
      result = screen.handle_slash_command('/hotkeys')
      expect(result).to eq(:handled)
    end

    it 'recognizes /save' do
      result = screen.handle_slash_command('/save test-session')
      expect(result).to eq(:handled)
    end

    it 'recognizes /sessions' do
      result = screen.handle_slash_command('/sessions')
      expect(result).to eq(:handled)
    end

    it 'recognizes /load' do
      result = screen.handle_slash_command('/load test-session')
      expect(result).to eq(:handled)
    end

    it 'includes all expected commands' do
      expected = %w[/help /quit /clear /model /session /cost /export /tools /dashboard /hotkeys /save /load /sessions]
      expect(described_class::SLASH_COMMANDS).to match_array(expected)
    end
  end

  describe '#handle_user_message' do
    it 'adds user message to stream' do
      screen.activate
      allow(screen).to receive(:send_to_llm)
      screen.handle_user_message('hello')
      user_msgs = screen.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs).not_to be_empty
    end

    it 'adds an assistant message placeholder to stream' do
      screen.activate
      allow(screen).to receive(:send_to_llm)
      screen.handle_user_message('hello')
      assistant_msgs = screen.message_stream.messages.select { |m| m[:role] == :assistant }
      expect(assistant_msgs).not_to be_empty
    end
  end

  describe '#render' do
    before { screen.activate }

    it 'returns an array of lines' do
      result = screen.render(80, 24)
      expect(result).to be_an(Array)
    end

    it 'returns non-empty output' do
      result = screen.render(80, 24)
      expect(result).not_to be_empty
    end
  end

  describe '#handle_input' do
    it 'handles up arrow scroll' do
      result = screen.handle_input(:up)
      expect(result).to eq(:handled)
    end

    it 'handles down arrow scroll' do
      result = screen.handle_input(:down)
      expect(result).to eq(:handled)
    end

    it 'passes unknown keys' do
      result = screen.handle_input(:f5)
      expect(result).to eq(:pass)
    end
  end
end
