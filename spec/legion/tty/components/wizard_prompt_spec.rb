# frozen_string_literal: true

require 'spec_helper'
require 'tty-prompt'
require 'legion/tty/components/wizard_prompt'

RSpec.describe Legion::TTY::Components::WizardPrompt do
  let(:mock_prompt) { instance_double(TTY::Prompt) }
  subject(:wizard) { described_class.new(prompt: mock_prompt) }

  describe '#initialize' do
    it 'accepts an injected prompt' do
      expect(wizard).to be_a(described_class)
    end

    it 'creates a default prompt when none injected' do
      allow(TTY::Prompt).to receive(:new).and_return(mock_prompt)
      instance = described_class.new
      expect(instance).to be_a(described_class)
    end
  end

  describe '#ask_name' do
    it 'calls ask on the prompt and returns the result' do
      allow(mock_prompt).to receive(:ask).with(
        'What should I call you?',
        hash_including(required: true)
      ).and_return('Alice')
      expect(wizard.ask_name).to eq('Alice')
    end
  end

  describe '#select_provider' do
    it 'calls select on the prompt and returns the result' do
      allow(mock_prompt).to receive(:select).and_return('claude')
      result = wizard.select_provider
      expect(result).to eq('claude')
    end

    it 'passes all provider choices' do
      expected_choices = hash_including(
        'Claude (Anthropic)' => 'claude',
        'OpenAI' => 'openai',
        'Gemini (Google)' => 'gemini',
        'Azure OpenAI' => 'azure',
        'Local (Ollama/LM Studio)' => 'local'
      )
      allow(mock_prompt).to receive(:select).with(anything, expected_choices).and_return('openai')
      wizard.select_provider
    end
  end

  describe '#ask_api_key' do
    it 'calls mask on the prompt and returns the result' do
      allow(mock_prompt).to receive(:mask).and_return('sk-abc123')
      result = wizard.ask_api_key(provider: 'claude')
      expect(result).to eq('sk-abc123')
    end

    it 'includes the provider name in the prompt text' do
      allow(mock_prompt).to receive(:mask).with(/claude/i).and_return('key')
      wizard.ask_api_key(provider: 'claude')
    end
  end

  describe '#confirm' do
    it 'calls yes? and returns true' do
      allow(mock_prompt).to receive(:yes?).with('Proceed?').and_return(true)
      expect(wizard.confirm('Proceed?')).to be(true)
    end

    it 'calls yes? and returns false' do
      allow(mock_prompt).to receive(:yes?).with('Are you sure?').and_return(false)
      expect(wizard.confirm('Are you sure?')).to be(false)
    end
  end

  describe '#select_from' do
    it 'calls select with the given question and choices' do
      choices = %w[alpha beta gamma]
      allow(mock_prompt).to receive(:select).with('Pick one', choices).and_return('beta')
      expect(wizard.select_from('Pick one', choices)).to eq('beta')
    end
  end

  describe '#ask_secret' do
    it 'calls mask on the prompt and returns the result' do
      allow(mock_prompt).to receive(:mask).with('Password:').and_return('s3cr3t')
      expect(wizard.ask_secret('Password:')).to eq('s3cr3t')
    end

    it 'delegates to prompt mask with the given question' do
      expect(mock_prompt).to receive(:mask).with('Enter token:').and_return('abc')
      wizard.ask_secret('Enter token:')
    end
  end

  describe '#ask_with_default' do
    it 'calls ask with the question and default option' do
      allow(mock_prompt).to receive(:ask).with('Username:', default: 'jdoe').and_return('jdoe')
      expect(wizard.ask_with_default('Username:', 'jdoe')).to eq('jdoe')
    end

    it 'returns the user-entered value when overridden' do
      allow(mock_prompt).to receive(:ask).with('Username:', default: 'jdoe').and_return('jsmith')
      expect(wizard.ask_with_default('Username:', 'jdoe')).to eq('jsmith')
    end
  end
end
