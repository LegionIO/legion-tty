# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/token_tracker'

RSpec.describe Legion::TTY::Components::TokenTracker do
  subject(:tracker) { described_class.new(provider: 'claude') }

  describe '#initialize' do
    it 'starts with zero input tokens' do
      expect(tracker.total_input_tokens).to eq(0)
    end

    it 'starts with zero output tokens' do
      expect(tracker.total_output_tokens).to eq(0)
    end

    it 'starts with zero cost' do
      expect(tracker.total_cost).to eq(0.0)
    end

    it 'accepts a provider argument' do
      t = described_class.new(provider: 'openai')
      expect(t).to be_a(described_class)
    end

    it 'defaults to claude when no provider given' do
      t = described_class.new
      expect(t.total_cost).to eq(0.0)
    end

    it 'accepts a model argument' do
      t = described_class.new(provider: 'claude', model: 'claude-sonnet-4-6')
      expect(t).to be_a(described_class)
    end
  end

  describe '#update_model' do
    it 'changes the model used for future tracking' do
      tracker.update_model('claude-opus-4-6')
      tracker.track(input_tokens: 1000, output_tokens: 1000)
      # opus: 0.015/1K input + 0.075/1K output = 0.090
      expect(tracker.total_cost).to be_within(0.0001).of(0.090)
    end
  end

  describe '#track' do
    it 'accumulates input tokens' do
      tracker.track(input_tokens: 100, output_tokens: 0)
      tracker.track(input_tokens: 200, output_tokens: 0)
      expect(tracker.total_input_tokens).to eq(300)
    end

    it 'accumulates output tokens' do
      tracker.track(input_tokens: 0, output_tokens: 50)
      tracker.track(input_tokens: 0, output_tokens: 75)
      expect(tracker.total_output_tokens).to eq(125)
    end

    it 'calculates cost using claude provider pricing as fallback' do
      tracker.track(input_tokens: 1000, output_tokens: 1000)
      # claude provider: 0.003/1K input + 0.015/1K output = 0.018
      expect(tracker.total_cost).to be_within(0.0001).of(0.018)
    end

    it 'handles nil tokens gracefully' do
      tracker.track(input_tokens: nil, output_tokens: nil)
      expect(tracker.total_input_tokens).to eq(0)
      expect(tracker.total_output_tokens).to eq(0)
    end

    it 'uses per-model rates when model kwarg is provided' do
      tracker.track(input_tokens: 1000, output_tokens: 1000, model: 'claude-sonnet-4-6')
      # sonnet: 0.003/1K input + 0.015/1K output = 0.018
      expect(tracker.total_cost).to be_within(0.0001).of(0.018)
    end

    it 'updates stored model when model kwarg is provided' do
      tracker.track(input_tokens: 0, output_tokens: 0, model: 'gpt-4o')
      tracker.track(input_tokens: 1000, output_tokens: 1000)
      # gpt-4o: 0.0025/1K input + 0.010/1K output = 0.0125
      expect(tracker.total_cost).to be_within(0.0001).of(0.0125)
    end
  end

  describe '#summary' do
    it 'returns a string' do
      expect(tracker.summary).to be_a(String)
    end

    it 'includes token counts' do
      tracker.track(input_tokens: 1500, output_tokens: 500)
      summary = tracker.summary
      expect(summary).to include('1,500 in')
      expect(summary).to include('500 out')
    end

    it 'includes cost' do
      tracker.track(input_tokens: 1000, output_tokens: 1000)
      expect(tracker.summary).to include('$0.0180')
    end

    it 'shows zero when no tracking done' do
      expect(tracker.summary).to include('0 in')
      expect(tracker.summary).to include('0 out')
      expect(tracker.summary).to include('$0.0000')
    end
  end

  describe 'per-model pricing' do
    it 'uses sonnet rates for claude-sonnet-4-6' do
      t = described_class.new(provider: 'claude', model: 'claude-sonnet-4-6')
      t.track(input_tokens: 1000, output_tokens: 1000)
      # sonnet: 0.003/1K + 0.015/1K = 0.018
      expect(t.total_cost).to be_within(0.0001).of(0.018)
    end

    it 'uses opus rates for claude-opus-4-6' do
      t = described_class.new(provider: 'claude', model: 'claude-opus-4-6')
      t.track(input_tokens: 1000, output_tokens: 1000)
      # opus: 0.015/1K + 0.075/1K = 0.090
      expect(t.total_cost).to be_within(0.0001).of(0.090)
    end

    it 'matches partial model name for bedrock-style model IDs' do
      t = described_class.new(provider: 'bedrock', model: 'us.anthropic.claude-sonnet-4-6-v1')
      t.track(input_tokens: 1000, output_tokens: 1000)
      # matches claude-sonnet-4-6: 0.003/1K + 0.015/1K = 0.018
      expect(t.total_cost).to be_within(0.0001).of(0.018)
    end

    it 'uses zero cost for local model' do
      t = described_class.new(provider: 'ollama', model: 'local')
      t.track(input_tokens: 10_000, output_tokens: 10_000)
      expect(t.total_cost).to eq(0.0)
    end
  end

  describe 'provider pricing fallback' do
    it 'uses openai pricing when provider is openai and no model given' do
      t = described_class.new(provider: 'openai')
      t.track(input_tokens: 1000, output_tokens: 1000)
      # openai: 0.0025/1K input + 0.010/1K output = 0.0125
      expect(t.total_cost).to be_within(0.0001).of(0.0125)
    end

    it 'uses zero pricing for local provider' do
      t = described_class.new(provider: 'local')
      t.track(input_tokens: 10_000, output_tokens: 10_000)
      expect(t.total_cost).to eq(0.0)
    end

    it 'falls back to claude pricing for unknown provider' do
      t = described_class.new(provider: 'unknown')
      t.track(input_tokens: 1000, output_tokens: 1000)
      expect(t.total_cost).to be_within(0.0001).of(0.018)
    end

    it 'falls back to claude pricing for unknown model and unknown provider' do
      t = described_class.new(provider: 'unknown', model: 'totally-fake-model')
      t.track(input_tokens: 1000, output_tokens: 1000)
      expect(t.total_cost).to be_within(0.0001).of(0.018)
    end
  end

  describe 'PROVIDER_PRICING' do
    it 'includes all expected providers' do
      expect(described_class::PROVIDER_PRICING.keys).to include('claude', 'openai', 'gemini', 'azure', 'local',
                                                                 'anthropic', 'bedrock', 'ollama')
    end

    it 'each provider has input and output rates' do
      described_class::PROVIDER_PRICING.each_value do |rates|
        expect(rates).to have_key(:input)
        expect(rates).to have_key(:output)
      end
    end
  end

  describe 'MODEL_PRICING' do
    it 'includes all expected models' do
      expect(described_class::MODEL_PRICING.keys).to include(
        'claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5',
        'gpt-4o', 'gpt-4o-mini', 'gpt-4.1',
        'gemini-2.0-flash', 'gemini-2.5-pro', 'local'
      )
    end

    it 'each model has input and output rates' do
      described_class::MODEL_PRICING.each_value do |rates|
        expect(rates).to have_key(:input)
        expect(rates).to have_key(:output)
      end
    end
  end
end
