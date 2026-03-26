# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat do
  let(:app) { double('app', config: { name: 'Test', provider: 'claude' }) }
  let(:output) { StringIO.new }
  let(:mock_input_bar) do
    instance_double(Legion::TTY::Components::InputBar,
                    prompt_string: '> ',
                    show_thinking: nil,
                    clear_thinking: nil,
                    thinking?: false)
  end

  # A fake DaemonClient class with the required interface for verify_partial_doubles
  let(:daemon_client_available) do
    Class.new do
      def self.available?
        true
      end
    end
  end

  let(:daemon_client_unavailable) do
    Class.new do
      def self.available?
        false
      end
    end
  end

  # A fake Legion::LLM module with .ask for verify_partial_doubles
  let(:fake_llm_module) do
    Module.new do
      def self.ask(**)
        nil
      end
    end
  end

  subject(:screen) { described_class.new(app, output: output, input_bar: mock_input_bar) }

  before { allow(app).to receive(:respond_to?).and_return(false) }

  describe '#daemon_available?' do
    context 'when Legion::LLM::DaemonClient is not defined' do
      before { hide_const('Legion::LLM::DaemonClient') if defined?(Legion::LLM::DaemonClient) }

      it 'returns false' do
        expect(screen.send(:daemon_available?)).to be false
      end
    end

    context 'when Legion::LLM::DaemonClient is defined but not available' do
      before { stub_const('Legion::LLM::DaemonClient', daemon_client_unavailable) }

      it 'returns false' do
        expect(screen.send(:daemon_available?)).to be false
      end
    end

    context 'when Legion::LLM::DaemonClient is defined and available' do
      before { stub_const('Legion::LLM::DaemonClient', daemon_client_available) }

      it 'returns true' do
        expect(screen.send(:daemon_available?)).to be true
      end
    end
  end

  describe '#send_to_llm routing' do
    context 'when neither daemon nor llm_chat is available' do
      before do
        hide_const('Legion::LLM::DaemonClient') if defined?(Legion::LLM::DaemonClient)
        screen.instance_variable_set(:@llm_chat, nil)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'shows not configured message' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with('LLM not configured. Use /help for commands.')
      end

      it 'does not raise an error' do
        expect { screen.send(:send_to_llm, 'hello') }.not_to raise_error
      end
    end

    context 'when daemon is available and returns a successful response' do
      let(:daemon_response) { { status: :done, response: 'Hello from daemon!' } }

      before do
        stub_const('Legion::LLM', fake_llm_module)
        stub_const('Legion::LLM::DaemonClient', daemon_client_available)
        allow(Legion::LLM).to receive(:ask).with(message: 'hello').and_return(daemon_response)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'calls append_streaming with the daemon response content' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming).with('Hello from daemon!')
      end
    end

    context 'when daemon is available and returns an error response' do
      let(:error_response) { { status: :error, error: { message: 'timeout' } } }

      before do
        stub_const('Legion::LLM', fake_llm_module)
        stub_const('Legion::LLM::DaemonClient', daemon_client_available)
        allow(Legion::LLM).to receive(:ask).with(message: 'hello').and_return(error_response)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'appends a daemon error message to the stream' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with("\n[Daemon error: timeout]")
      end
    end

    context 'when daemon is available and returns an error response with no message' do
      let(:error_response) { { status: :error, error: {} } }

      before do
        stub_const('Legion::LLM', fake_llm_module)
        stub_const('Legion::LLM::DaemonClient', daemon_client_available)
        allow(Legion::LLM).to receive(:ask).with(message: 'hello').and_return(error_response)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'appends a generic daemon error message' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with("\n[Daemon error: Unknown error]")
      end
    end

    context 'when daemon is available but Legion::LLM.ask raises an exception' do
      let(:llm_chat) { double('llm_chat') }
      let(:fake_response) { double('response', input_tokens: nil) }

      before do
        stub_const('Legion::LLM', fake_llm_module)
        stub_const('Legion::LLM::DaemonClient', daemon_client_available)
        allow(Legion::LLM).to receive(:ask).and_raise(StandardError, 'connection refused')
        screen.instance_variable_set(:@llm_chat, llm_chat)
        allow(llm_chat).to receive(:ask).and_yield(double(content: 'direct chunk')).and_return(fake_response)
        allow(screen.message_stream).to receive(:append_streaming)
        allow(screen).to receive(:track_response_tokens)
      end

      it 'falls back to direct LLM path' do
        screen.send(:send_to_llm, 'hello')
        expect(llm_chat).to have_received(:ask)
      end

      it 'streams the direct response chunk' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming).with('direct chunk')
      end
    end

    context 'when daemon returns an unknown status (falls back to direct)' do
      let(:llm_chat) { double('llm_chat') }
      let(:fake_response) { double('response', input_tokens: nil) }
      let(:unknown_response) { { status: :unknown } }

      before do
        stub_const('Legion::LLM', fake_llm_module)
        stub_const('Legion::LLM::DaemonClient', daemon_client_available)
        allow(Legion::LLM).to receive(:ask).with(message: 'hello').and_return(unknown_response)
        screen.instance_variable_set(:@llm_chat, llm_chat)
        allow(llm_chat).to receive(:ask).and_yield(double(content: 'fallback')).and_return(fake_response)
        allow(screen.message_stream).to receive(:append_streaming)
        allow(screen).to receive(:track_response_tokens)
      end

      it 'falls back to direct path' do
        screen.send(:send_to_llm, 'hello')
        expect(llm_chat).to have_received(:ask)
      end
    end

    context 'when daemon is unavailable and llm_chat is configured (direct path)' do
      let(:llm_chat) { double('llm_chat') }
      let(:fake_response) { double('response', input_tokens: nil) }

      before do
        hide_const('Legion::LLM::DaemonClient') if defined?(Legion::LLM::DaemonClient)
        screen.instance_variable_set(:@llm_chat, llm_chat)
        allow(llm_chat).to receive(:ask).and_yield(double(content: 'streamed chunk')).and_return(fake_response)
        allow(screen.message_stream).to receive(:append_streaming)
        allow(screen).to receive(:track_response_tokens)
      end

      it 'calls llm_chat.ask with the message' do
        screen.send(:send_to_llm, 'hello')
        expect(llm_chat).to have_received(:ask).with('hello')
      end

      it 'streams chunks via append_streaming' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming).with('streamed chunk')
      end

      it 'calls track_response_tokens with the response' do
        screen.send(:send_to_llm, 'hello')
        expect(screen).to have_received(:track_response_tokens).with(fake_response)
      end
    end

    context 'when daemon is unavailable and llm_chat is nil' do
      before do
        hide_const('Legion::LLM::DaemonClient') if defined?(Legion::LLM::DaemonClient)
        screen.instance_variable_set(:@llm_chat, nil)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'shows not configured message and does not crash' do
        expect { screen.send(:send_to_llm, 'hello') }.not_to raise_error
        expect(screen.message_stream).to have_received(:append_streaming)
          .with('LLM not configured. Use /help for commands.')
      end
    end
  end

  describe '#send_via_direct' do
    context 'when llm_chat is nil' do
      before do
        screen.instance_variable_set(:@llm_chat, nil)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'returns without raising' do
        expect { screen.send(:send_via_direct, 'hello') }.not_to raise_error
      end

      it 'does not call append_streaming' do
        screen.send(:send_via_direct, 'hello')
        expect(screen.message_stream).not_to have_received(:append_streaming)
      end
    end

    context 'when llm_chat is configured with nil chunk content' do
      let(:llm_chat) { double('llm_chat') }
      let(:fake_response) { double('response', input_tokens: nil) }

      before do
        screen.instance_variable_set(:@llm_chat, llm_chat)
        allow(llm_chat).to receive(:ask).and_yield(double(content: nil)).and_return(fake_response)
        allow(screen).to receive(:track_response_tokens)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'does not call append_streaming for nil chunk content' do
        screen.send(:send_via_direct, 'hello')
        expect(screen.message_stream).not_to have_received(:append_streaming)
      end
    end
  end

  describe 'StandardError rescue in send_to_llm' do
    before do
      hide_const('Legion::LLM::DaemonClient') if defined?(Legion::LLM::DaemonClient)
      llm = double('llm_chat')
      screen.instance_variable_set(:@llm_chat, llm)
      allow(llm).to receive(:ask).and_raise(StandardError, 'boom')
      allow(screen.message_stream).to receive(:append_streaming)
    end

    it 'rescues and appends error message' do
      screen.send(:send_to_llm, 'hello')
      expect(screen.message_stream).to have_received(:append_streaming).with("\n[Error: boom]")
    end
  end
end
