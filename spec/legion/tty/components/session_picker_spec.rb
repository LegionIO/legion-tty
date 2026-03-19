# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/session_picker'

RSpec.describe Legion::TTY::Components::SessionPicker do
  let(:session_store) { double('session_store') }
  subject(:picker) { described_class.new(session_store: session_store) }

  describe '#initialize' do
    it 'accepts a session_store' do
      expect(picker).to be_a(described_class)
    end
  end

  describe '#select_with_prompt' do
    context 'when no sessions exist' do
      before do
        allow(session_store).to receive(:list).and_return([])
      end

      it 'returns nil without prompting' do
        expect(picker.select_with_prompt).to be_nil
      end
    end

    context 'when sessions exist' do
      let(:sessions) do
        [
          { name: 'my-session', message_count: 5, saved_at: '2026-03-01' },
          { name: 'work', message_count: 12, saved_at: '2026-03-10' }
        ]
      end

      before do
        allow(session_store).to receive(:list).and_return(sessions)
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

      it 'builds choices including a new session option' do
        prompt_double = double('TTY::Prompt')
        captured_choices = nil
        allow(prompt_double).to receive(:select) do |_label, choices, _opts|
          captured_choices = choices
          raise Interrupt
        end
        allow(TTY::Prompt).to receive(:new).and_return(prompt_double)

        picker.select_with_prompt

        values = captured_choices.map { |c| c[:value] }
        expect(values).to include('my-session', 'work', :new)
      end

      it 'includes message count and saved_at in choice names' do
        prompt_double = double('TTY::Prompt')
        captured_choices = nil
        allow(prompt_double).to receive(:select) do |_label, choices, _opts|
          captured_choices = choices
          raise Interrupt
        end
        allow(TTY::Prompt).to receive(:new).and_return(prompt_double)

        picker.select_with_prompt

        names = captured_choices.map { |c| c[:name] }
        expect(names.first).to include('my-session', '5 msgs', '2026-03-01')
      end
    end
  end
end
