# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/background/llm_probe'

RSpec.describe Legion::TTY::Background::LlmProbe do
  subject(:probe) { described_class.new }

  describe '#initialize' do
    it 'accepts a logger keyword arg' do
      logger = double('logger')
      instance = described_class.new(logger: logger)
      expect(instance).to be_a(described_class)
    end

    it 'accepts a wait_queue keyword arg' do
      q = Queue.new
      instance = described_class.new(wait_queue: q)
      expect(instance).to be_a(described_class)
    end

    it 'defaults wait_queue to nil' do
      instance = described_class.new
      expect(instance.instance_variable_get(:@wait_queue)).to be_nil
    end
  end

  describe '#run_async' do
    let(:queue) { Queue.new }

    it 'pushes a result hash onto the queue' do
      allow(probe).to receive(:probe_providers).and_return({ providers: [] })
      probe.run_async(queue)
      result = queue.pop
      expect(result).to have_key(:data)
    end

    it 'pushes an error hash when probe_providers raises' do
      allow(probe).to receive(:probe_providers).and_raise(StandardError, 'boom')
      probe.run_async(queue)
      result = queue.pop
      expect(result[:data]).to include(providers: [], error: 'boom')
    end

    context 'with a wait_queue' do
      let(:wait_queue) { Queue.new }
      subject(:probe_with_wait) { described_class.new(wait_queue: wait_queue) }

      it 'waits until the wait_queue is non-empty before probing' do
        call_order = []
        allow(probe_with_wait).to receive(:probe_providers) do
          call_order << :probe
          { providers: [] }
        end

        thread = probe_with_wait.run_async(queue)
        sleep 0.05
        call_order << :bootstrap_done
        wait_queue.push({ type: :bootstrap_complete })
        thread.join(2)

        expect(call_order).to eq(%i[bootstrap_done probe])
      end
    end
  end

  describe '#ping_provider' do
    let(:config) { { default_model: 'claude-3-haiku' } }

    def stub_ruby_llm_success
      chat_dbl = double('chat', ask: 'pong')
      ruby_llm_mod = Module.new { def self.chat(**_kwargs); end }
      allow(ruby_llm_mod).to receive(:chat).and_return(chat_dbl)
      stub_const('RubyLLM', ruby_llm_mod)
    end

    def stub_ruby_llm_error(message)
      err = message
      ruby_llm_mod = Module.new { def self.chat(**_kwargs); end }
      allow(ruby_llm_mod).to receive(:chat).and_raise(StandardError, err)
      stub_const('RubyLLM', ruby_llm_mod)
    end

    it 'returns :ok status when RubyLLM succeeds' do
      stub_ruby_llm_success
      result = probe.send(:ping_provider, :claude, config)
      expect(result[:status]).to eq(:ok)
      expect(result[:name]).to eq(:claude)
    end

    it 'returns :configured status when RubyLLM raises' do
      stub_ruby_llm_error('unknown provider')
      result = probe.send(:ping_provider, :foundry, config)
      expect(result[:status]).to eq(:configured)
      expect(result[:error]).to eq('unknown provider')
    end

    it 'includes latency_ms in all outcomes' do
      stub_ruby_llm_error('err')
      result = probe.send(:ping_provider, :xai, config)
      expect(result).to have_key(:latency_ms)
    end
  end
end
