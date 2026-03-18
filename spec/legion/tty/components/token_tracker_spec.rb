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

    it 'calculates cost using claude pricing' do
      tracker.track(input_tokens: 1000, output_tokens: 1000)
      # claude: 0.003/1K input + 0.015/1K output = 0.003 + 0.015 = 0.018
      expect(tracker.total_cost).to be_within(0.0001).of(0.018)
    end

    it 'handles nil tokens gracefully' do
      tracker.track(input_tokens: nil, output_tokens: nil)
      expect(tracker.total_input_tokens).to eq(0)
      expect(tracker.total_output_tokens).to eq(0)
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

  describe 'provider pricing' do
    it 'uses openai pricing when provider is openai' do
      t = described_class.new(provider: 'openai')
      t.track(input_tokens: 1000, output_tokens: 1000)
      # openai: 0.005/1K input + 0.015/1K output = 0.020
      expect(t.total_cost).to be_within(0.0001).of(0.020)
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
  end

  describe 'PRICING' do
    it 'includes all expected providers' do
      expect(described_class::PRICING.keys).to include('claude', 'openai', 'gemini', 'azure', 'local')
    end

    it 'each provider has input and output rates' do
      described_class::PRICING.each_value do |rates|
        expect(rates).to have_key(:input)
        expect(rates).to have_key(:output)
      end
    end
  end
end
