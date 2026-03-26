# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '#build_system_prompt' do
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

  let(:cfg) { { name: 'Test', provider: 'claude' } }

  describe 'self-awareness injection' do
    context 'when lex-agentic-self is loaded' do
      before do
        runners_mod = Module.new do
          def self.self_narrative
            { prose: 'I am a brain_modeled cognitive_agent with 47 active extensions.' }
          end
        end

        metacog_mod = Module.new
        metacog_mod.const_set(:Runners, Module.new)
        metacog_mod::Runners.const_set(:Metacognition, runners_mod)

        agentic_mod = Module.new
        agentic_mod.const_set(:Metacognition, metacog_mod)

        self_mod = Module.new
        self_mod.const_set(:Metacognition, metacog_mod)

        extensions_mod = Module.new
        extensions_mod.const_set(:Agentic, Module.new)
        extensions_mod::Agentic.const_set(:Self, self_mod)

        stub_const('Legion::Extensions::Agentic::Self::Metacognition::Runners::Metacognition', runners_mod)
      end

      it 'includes the self-awareness section in the system prompt' do
        result = screen.send(:build_system_prompt, cfg)
        expect(result).to include('Current self-awareness:')
      end

      it 'includes the narrative prose in the system prompt' do
        result = screen.send(:build_system_prompt, cfg)
        expect(result).to include('I am a brain_modeled cognitive_agent with 47 active extensions.')
      end
    end

    context 'when lex-agentic-self is NOT loaded' do
      it 'does not include the self-awareness section' do
        result = screen.send(:build_system_prompt, cfg)
        expect(result).not_to include('Current self-awareness:')
      end

      it 'still returns a valid system prompt' do
        result = screen.send(:build_system_prompt, cfg)
        expect(result).to include('You are Legion')
      end
    end

    context 'when self_narrative raises an exception' do
      before do
        runners_mod = Module.new do
          def self.self_narrative
            raise StandardError, 'metacognition unavailable'
          end
        end
        stub_const('Legion::Extensions::Agentic::Self::Metacognition::Runners::Metacognition', runners_mod)
      end

      it 'does not raise' do
        expect { screen.send(:build_system_prompt, cfg) }.not_to raise_error
      end

      it 'does not include the self-awareness section' do
        result = screen.send(:build_system_prompt, cfg)
        expect(result).not_to include('Current self-awareness:')
      end

      it 'still returns a valid system prompt' do
        result = screen.send(:build_system_prompt, cfg)
        expect(result).to include('You are Legion')
      end
    end
  end
end
