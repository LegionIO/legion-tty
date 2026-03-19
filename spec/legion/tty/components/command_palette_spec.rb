# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/command_palette'

RSpec.describe Legion::TTY::Components::CommandPalette do
  subject(:palette) { described_class.new }

  describe '#entries' do
    it 'returns commands' do
      labels = palette.entries.map { |e| e[:label] }
      expect(labels).to include('/help', '/quit', '/clear', '/model')
    end

    it 'returns screens' do
      labels = palette.entries.map { |e| e[:label] }
      expect(labels).to include('chat', 'dashboard', 'extensions', 'config')
    end

    it 'assigns Commands category to commands' do
      cmd_entry = palette.entries.find { |e| e[:label] == '/help' }
      expect(cmd_entry[:category]).to eq('Commands')
    end

    it 'assigns Screens category to screens' do
      screen_entry = palette.entries.find { |e| e[:label] == 'chat' }
      expect(screen_entry[:category]).to eq('Screens')
    end

    context 'with a session_store' do
      let(:session_store) do
        store = double('session_store')
        allow(store).to receive(:list).and_return([
                                                    { name: 'my-session', message_count: 5, saved_at: '2026-03-01' },
                                                    { name: 'work', message_count: 12, saved_at: '2026-03-10' }
                                                  ])
        store
      end
      subject(:palette_with_store) { described_class.new(session_store: session_store) }

      it 'includes session load entries' do
        labels = palette_with_store.entries.map { |e| e[:label] }
        expect(labels).to include('/load my-session', '/load work')
      end

      it 'assigns Sessions category to session entries' do
        session_entry = palette_with_store.entries.find { |e| e[:label] == '/load my-session' }
        expect(session_entry[:category]).to eq('Sessions')
      end
    end

    context 'with nil session_store' do
      it 'works without sessions' do
        result = palette.entries
        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end

      it 'does not include Sessions category entries' do
        categories = palette.entries.map { |e| e[:category] }.uniq
        expect(categories).not_to include('Sessions')
      end
    end
  end

  describe '#search' do
    it 'filters by query string' do
      results = palette.search('quit')
      labels = results.map { |e| e[:label] }
      expect(labels).to include('/quit')
      expect(labels).not_to include('/help')
    end

    it 'returns all entries when query is nil' do
      expect(palette.search(nil)).to eq(palette.entries)
    end

    it 'returns all entries when query is empty string' do
      expect(palette.search('')).to eq(palette.entries)
    end

    it 'is case-insensitive' do
      results_lower = palette.search('model')
      results_upper = palette.search('MODEL')
      expect(results_lower).to eq(results_upper)
    end

    it 'returns empty array when no match' do
      results = palette.search('zzznomatch')
      expect(results).to be_empty
    end

    it 'matches partial strings' do
      results = palette.search('dash')
      labels = results.map { |e| e[:label] }
      expect(labels).to include('/dashboard', 'dashboard')
    end
  end

  describe '#select_with_prompt' do
    it 'rescues Interrupt and returns nil' do
      prompt_double = double('TTY::Prompt')
      allow(prompt_double).to receive(:select).and_raise(Interrupt)
      allow(TTY::Prompt).to receive(:new).and_return(prompt_double)

      result = palette.select_with_prompt
      expect(result).to be_nil
    end

    it 'rescues TTY::Reader::InputInterrupt and returns nil' do
      prompt_double = double('TTY::Prompt')
      allow(prompt_double).to receive(:select).and_raise(TTY::Reader::InputInterrupt)
      allow(TTY::Prompt).to receive(:new).and_return(prompt_double)

      result = palette.select_with_prompt
      expect(result).to be_nil
    end
  end
end
