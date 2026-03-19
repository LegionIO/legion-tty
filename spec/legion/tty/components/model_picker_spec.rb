# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/model_picker'

RSpec.describe Legion::TTY::Components::ModelPicker do
  subject(:picker) { described_class.new }

  describe '#available_models' do
    context 'when Legion::LLM is not defined' do
      before do
        hide_const('Legion::LLM') if defined?(Legion::LLM)
      end

      it 'returns empty array' do
        expect(picker.available_models).to eq([])
      end
    end

    context 'when Legion::LLM is defined but has no settings' do
      before do
        stub_const('Legion::LLM', Module.new)
        allow(Legion::LLM).to receive(:respond_to?).with(any_args).and_return(false)
      end

      it 'returns empty array' do
        expect(picker.available_models).to eq([])
      end
    end

    context 'when Legion::LLM is configured with providers' do
      let(:llm_settings) do
        {
          providers: {
            claude: { enabled: true, default_model: 'claude-3-opus' },
            openai: { enabled: true, default_model: 'gpt-4o' },
            gemini: { enabled: false, default_model: 'gemini-pro' }
          }
        }
      end

      before do
        stub_const('Legion::LLM', Module.new)
        allow(Legion::LLM).to receive(:respond_to?).with(any_args).and_return(true)
        allow(Legion::LLM).to receive(:settings).and_return(llm_settings)
      end

      it 'returns enabled providers as models' do
        models = picker.available_models
        providers = models.map { |m| m[:provider] }
        expect(providers).to include('claude', 'openai')
      end

      it 'skips disabled providers' do
        models = picker.available_models
        providers = models.map { |m| m[:provider] }
        expect(providers).not_to include('gemini')
      end

      it 'includes the default_model for each provider' do
        models = picker.available_models
        claude_entry = models.find { |m| m[:provider] == 'claude' }
        expect(claude_entry[:model]).to eq('claude-3-opus')
      end

      it 'marks the current provider' do
        current_picker = described_class.new(current_provider: 'claude')
        allow(Legion::LLM).to receive(:settings).and_return(llm_settings)
        models = current_picker.available_models
        claude_entry = models.find { |m| m[:provider] == 'claude' }
        openai_entry = models.find { |m| m[:provider] == 'openai' }
        expect(claude_entry[:current]).to be true
        expect(openai_entry[:current]).to be false
      end

      it 'falls back to provider name when no default_model' do
        settings_no_model = {
          providers: {
            myservice: { enabled: true }
          }
        }
        allow(Legion::LLM).to receive(:settings).and_return(settings_no_model)
        models = picker.available_models
        entry = models.find { |m| m[:provider] == 'myservice' }
        expect(entry[:model]).to eq('myservice')
      end
    end

    context 'when providers is not a Hash' do
      before do
        stub_const('Legion::LLM', Module.new)
        allow(Legion::LLM).to receive(:respond_to?).with(any_args).and_return(true)
        allow(Legion::LLM).to receive(:settings).and_return({ providers: nil })
      end

      it 'returns empty array' do
        expect(picker.available_models).to eq([])
      end
    end
  end

  describe '#select_with_prompt' do
    context 'when no models are available' do
      before do
        allow(picker).to receive(:available_models).and_return([])
      end

      it 'returns nil without prompting' do
        expect(picker.select_with_prompt).to be_nil
      end
    end

    context 'when models are available' do
      let(:models) do
        [
          { provider: 'claude', model: 'claude-3-opus', current: true },
          { provider: 'openai', model: 'gpt-4o', current: false }
        ]
      end

      before do
        allow(picker).to receive(:available_models).and_return(models)
      end

      it 'rescues Interrupt and returns nil' do
        prompt_double = double('TTY::Prompt')
        allow(prompt_double).to receive(:select).and_raise(Interrupt)
        allow(TTY::Prompt).to receive(:new).and_return(prompt_double)

        result = picker.select_with_prompt
        expect(result).to be_nil
      end

      it 'rescues TTY::Reader::InputInterrupt and returns nil' do
        prompt_double = double('TTY::Prompt')
        allow(prompt_double).to receive(:select).and_raise(TTY::Reader::InputInterrupt)
        allow(TTY::Prompt).to receive(:new).and_return(prompt_double)

        result = picker.select_with_prompt
        expect(result).to be_nil
      end
    end
  end
end
