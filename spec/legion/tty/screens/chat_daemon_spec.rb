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

  subject(:screen) { described_class.new(app, output: output, input_bar: mock_input_bar) }

  before { allow(app).to receive(:respond_to?).and_return(false) }

  describe '#daemon_available?' do
    context 'when DaemonClient.available? returns false' do
      before { allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(false) }

      it 'returns false' do
        expect(screen.send(:daemon_available?)).to be false
      end
    end

    context 'when DaemonClient.available? returns true' do
      before { allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true) }

      it 'returns true' do
        expect(screen.send(:daemon_available?)).to be true
      end
    end

    context 'when DaemonClient.available? raises' do
      before { allow(Legion::TTY::DaemonClient).to receive(:available?).and_raise(StandardError, 'conn refused') }

      it 'returns false without raising' do
        expect(screen.send(:daemon_available?)).to be false
      end
    end
  end

  describe '#send_to_llm routing' do
    context 'when daemon is unavailable' do
      before do
        allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(false)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'shows daemon-not-running message' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with('LegionIO daemon is not running. Start it with: legionio start')
      end

      it 'does not raise an error' do
        expect { screen.send(:send_to_llm, 'hello') }.not_to raise_error
      end

      it 'does not call DaemonClient.inference' do
        expect(Legion::TTY::DaemonClient).not_to receive(:inference)
        screen.send(:send_to_llm, 'hello')
      end
    end

    context 'when daemon is available and returns a successful response' do
      let(:ok_result) { { status: :ok, data: { content: 'Hello from daemon!', input_tokens: 10, output_tokens: 5 } } }

      before do
        allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true)
        allow(Legion::TTY::DaemonClient).to receive(:inference).and_return(ok_result)
        allow(screen.message_stream).to receive(:append_streaming)
        allow(screen).to receive(:record_response_time)
      end

      it 'calls DaemonClient.inference with messages array' do
        expect(Legion::TTY::DaemonClient).to receive(:inference).with(hash_including(messages: Array))
        screen.send(:send_to_llm, 'hello')
      end

      it 'streams the response content' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming).with('Hello from daemon!')
      end

      it 'does not use @llm_chat' do
        expect(screen.instance_variable_get(:@llm_chat)).to be_nil
        screen.send(:send_to_llm, 'hello')
      end
    end

    context 'when daemon is available and returns an error response' do
      let(:error_result) { { status: :error, error: { message: 'timeout' } } }

      before do
        allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true)
        allow(Legion::TTY::DaemonClient).to receive(:inference).and_return(error_result)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'appends a daemon error message to the stream' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with("\n[Daemon error: timeout]")
      end

      it 'does not use @llm_chat directly' do
        expect(screen.instance_variable_get(:@llm_chat)).to be_nil
        screen.send(:send_to_llm, 'hello')
      end
    end

    context 'when daemon is available and returns an error response with no message' do
      let(:error_result) { { status: :error, error: {} } }

      before do
        allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true)
        allow(Legion::TTY::DaemonClient).to receive(:inference).and_return(error_result)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'appends a generic daemon error message' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with("\n[Daemon error: Unknown error]")
      end
    end

    context 'when daemon is available but inference raises an exception' do
      before do
        allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true)
        allow(Legion::TTY::DaemonClient).to receive(:inference).and_raise(StandardError, 'connection refused')
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'rescues and appends error to stream' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with("\n[Error: connection refused]")
      end

      it 'does not fall back to raw RubyLLM' do
        expect(screen.instance_variable_get(:@llm_chat)).to be_nil
        screen.send(:send_to_llm, 'hello')
      end
    end

    context 'when daemon returns unavailable status' do
      let(:unavailable_result) { { status: :unavailable, error: { message: 'connection refused' } } }

      before do
        allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true)
        allow(Legion::TTY::DaemonClient).to receive(:inference).and_return(unavailable_result)
        allow(screen.message_stream).to receive(:append_streaming)
      end

      it 'appends daemon-not-running message' do
        screen.send(:send_to_llm, 'hello')
        expect(screen.message_stream).to have_received(:append_streaming)
          .with(a_string_including('legionio start'))
      end
    end
  end

  describe '#build_inference_messages' do
    before do
      allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(false)
    end

    it 'includes a system message when config has data' do
      msgs = screen.send(:build_inference_messages, 'hello')
      system_msg = msgs.find { |m| m[:role] == 'system' }
      expect(system_msg).not_to be_nil
      expect(system_msg[:content]).to include('Legion')
    end

    it 'ends with the current user message' do
      msgs = screen.send(:build_inference_messages, 'my question')
      expect(msgs.last).to eq({ role: 'user', content: 'my question' })
    end

    it 'includes prior user/assistant messages from the stream' do
      screen.message_stream.add_message(role: :user, content: 'previous question')
      screen.message_stream.add_message(role: :assistant, content: 'previous answer')
      msgs = screen.send(:build_inference_messages, 'follow up')
      roles = msgs.map { |m| m[:role] }
      expect(roles).to include('user', 'assistant')
      expect(msgs.last[:content]).to eq('follow up')
    end

    it 'skips tool panel messages' do
      screen.message_stream.add_tool_call(name: 'read_file', args: {}, status: :complete)
      msgs = screen.send(:build_inference_messages, 'hello')
      expect(msgs.none? { |m| m[:role] == 'tool' }).to be true
    end
  end

  describe '#track_inference_tokens' do
    it 'tracks tokens from inference data hash' do
      data = { content: 'hi', input_tokens: 200, output_tokens: 80, model: 'claude-sonnet-4-6' }
      screen.send(:track_inference_tokens, data)
      tracker = screen.instance_variable_get(:@token_tracker)
      expect(tracker.total_input_tokens).to eq(200)
      expect(tracker.total_output_tokens).to eq(80)
    end

    it 'skips when data has no token keys' do
      data = { content: 'hi', model: 'test' }
      screen.send(:track_inference_tokens, data)
      tracker = screen.instance_variable_get(:@token_tracker)
      expect(tracker.total_input_tokens).to eq(0)
    end

    it 'skips when data is nil' do
      expect { screen.send(:track_inference_tokens, nil) }.not_to raise_error
    end
  end

  describe '#track_response_tokens' do
    it 'reads model_id from the response' do
      response = double('response', input_tokens: 100, output_tokens: 50, model_id: 'claude-sonnet-4-6')
      allow(response).to receive(:respond_to?).with(:input_tokens).and_return(true)
      allow(response).to receive(:respond_to?).with(:output_tokens).and_return(true)
      allow(response).to receive(:respond_to?).with(:model_id).and_return(true)
      screen.send(:track_response_tokens, response)
      tracker = screen.instance_variable_get(:@token_tracker)
      expect(tracker.total_input_tokens).to eq(100)
      expect(tracker.total_output_tokens).to eq(50)
    end

    it 'applies per-model pricing when model_id is set' do
      sonnet_screen = described_class.new(app, output: output, input_bar: mock_input_bar)
      opus_screen   = described_class.new(app, output: output, input_bar: mock_input_bar)

      sonnet_response = double('response', input_tokens: 200, output_tokens: 80, model_id: 'claude-sonnet-4-6')
      allow(sonnet_response).to receive(:respond_to?).with(:input_tokens).and_return(true)
      allow(sonnet_response).to receive(:respond_to?).with(:output_tokens).and_return(true)
      allow(sonnet_response).to receive(:respond_to?).with(:model_id).and_return(true)

      opus_response = double('response', input_tokens: 200, output_tokens: 80, model_id: 'claude-opus-4-6')
      allow(opus_response).to receive(:respond_to?).with(:input_tokens).and_return(true)
      allow(opus_response).to receive(:respond_to?).with(:output_tokens).and_return(true)
      allow(opus_response).to receive(:respond_to?).with(:model_id).and_return(true)

      sonnet_screen.send(:track_response_tokens, sonnet_response)
      opus_screen.send(:track_response_tokens, opus_response)

      sonnet_tracker = sonnet_screen.instance_variable_get(:@token_tracker)
      opus_tracker   = opus_screen.instance_variable_get(:@token_tracker)

      expect(sonnet_tracker.total_cost).not_to eq(opus_tracker.total_cost)
    end

    it 'skips when response does not have input_tokens' do
      response = double('response')
      allow(response).to receive(:respond_to?).with(:input_tokens).and_return(false)
      screen.send(:track_response_tokens, response)
      tracker = screen.instance_variable_get(:@token_tracker)
      expect(tracker.total_input_tokens).to eq(0)
    end
  end

  describe 'StandardError rescue in send_to_llm' do
    before do
      allow(Legion::TTY::DaemonClient).to receive(:available?).and_return(true)
      allow(Legion::TTY::DaemonClient).to receive(:inference).and_raise(StandardError, 'boom')
      allow(screen.message_stream).to receive(:append_streaming)
    end

    it 'rescues and appends error message' do
      screen.send(:send_to_llm, 'hello')
      expect(screen.message_stream).to have_received(:append_streaming).with("\n[Error: boom]")
    end
  end
end
