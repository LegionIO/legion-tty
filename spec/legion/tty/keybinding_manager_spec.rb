# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/json'
require 'legion/tty/keybinding_manager'

RSpec.describe Legion::TTY::KeybindingManager do
  let(:tmpdir) { Dir.mktmpdir }
  let(:overrides_path) { File.join(tmpdir, 'keybindings.json') }
  subject(:manager) { described_class.new(overrides_path: overrides_path) }

  after { FileUtils.remove_entry(tmpdir) }

  describe 'CONTEXTS constant' do
    it 'includes all required named contexts' do
      expected = %i[global chat dashboard extensions config command_palette session_picker history]
      expect(described_class::CONTEXTS).to match_array(expected)
    end
  end

  describe '#initialize' do
    it 'loads default bindings on construction' do
      expect(manager.list).not_to be_empty
    end

    it 'registers ctrl_d as toggle_dashboard by default' do
      action = manager.resolve(:ctrl_d, active_contexts: [:chat])
      expect(action).to eq(:toggle_dashboard)
    end

    it 'registers ctrl_k as command_palette by default' do
      expect(manager.resolve(:ctrl_k, active_contexts: [:chat])).to eq(:command_palette)
    end

    it 'registers ctrl_s as session_picker by default' do
      expect(manager.resolve(:ctrl_s, active_contexts: [:chat])).to eq(:session_picker)
    end

    it 'registers ctrl_l as refresh by default' do
      expect(manager.resolve(:ctrl_l, active_contexts: [:chat])).to eq(:refresh)
    end

    it 'registers escape as back across all contexts' do
      described_class::CONTEXTS.each do |ctx|
        expect(manager.resolve(:escape, active_contexts: [ctx])).to eq(:back)
      end
    end

    it 'registers ctrl_c as interrupt' do
      expect(manager.resolve(:ctrl_c, active_contexts: [:global])).to eq(:interrupt)
    end

    it 'registers tab as autocomplete in chat context' do
      expect(manager.resolve(:tab, active_contexts: [:chat])).to eq(:autocomplete)
    end
  end

  describe '#resolve' do
    it 'returns nil for an unregistered key' do
      expect(manager.resolve(:f12, active_contexts: [:global])).to be_nil
    end

    it 'returns nil when context does not match' do
      # tab is only in :chat, not :dashboard
      expect(manager.resolve(:tab, active_contexts: [:dashboard])).to be_nil
    end

    it 'matches when active_contexts overlaps binding contexts' do
      expect(manager.resolve(:ctrl_l, active_contexts: %i[chat dashboard])).to eq(:refresh)
    end

    it 'resolves global-context bindings regardless of active_contexts' do
      expect(manager.resolve(:escape, active_contexts: [:history])).to eq(:back)
    end

    it 'accepts string keys and normalizes to symbols' do
      expect(manager.resolve('ctrl_d', active_contexts: [:chat])).to eq(:toggle_dashboard)
    end
  end

  describe 'chord support' do
    before do
      manager.bind(:'ctrl_x+ctrl_c', action: :chord_quit, contexts: [:global], description: 'Chord quit')
    end

    it 'returns :chord_pending on the first key of a chord' do
      result = manager.resolve(:ctrl_x, active_contexts: [:global])
      expect(result).to eq(:chord_pending)
    end

    it 'is chord_pending? after the first key' do
      manager.resolve(:ctrl_x, active_contexts: [:global])
      expect(manager.chord_pending?).to be true
    end

    it 'resolves the chord action on the second key' do
      manager.resolve(:ctrl_x, active_contexts: [:global])
      action = manager.resolve(:ctrl_c, active_contexts: [:global])
      expect(action).to eq(:chord_quit)
    end

    it 'is no longer chord_pending? after resolution' do
      manager.resolve(:ctrl_x, active_contexts: [:global])
      manager.resolve(:ctrl_c, active_contexts: [:global])
      expect(manager.chord_pending?).to be false
    end

    it 'returns nil for an unrecognized second chord key and clears chord state' do
      manager.resolve(:ctrl_x, active_contexts: [:global])
      result = manager.resolve(:z, active_contexts: [:global])
      expect(result).to be_nil
      expect(manager.chord_pending?).to be false
    end

    it 'cancel_chord resets pending state' do
      manager.resolve(:ctrl_x, active_contexts: [:global])
      manager.cancel_chord
      expect(manager.chord_pending?).to be false
    end
  end

  describe '#bind' do
    it 'registers a new binding' do
      manager.bind(:ctrl_r, action: :reload, contexts: [:chat])
      expect(manager.resolve(:ctrl_r, active_contexts: [:chat])).to eq(:reload)
    end

    it 'overrides an existing binding' do
      manager.bind(:ctrl_d, action: :custom_action, contexts: [:global])
      expect(manager.resolve(:ctrl_d, active_contexts: [:chat])).to eq(:custom_action)
    end

    it 'does not match in wrong context' do
      manager.bind(:ctrl_r, action: :reload, contexts: [:chat])
      expect(manager.resolve(:ctrl_r, active_contexts: [:dashboard])).to be_nil
    end
  end

  describe '#unbind' do
    it 'removes a binding' do
      manager.unbind(:ctrl_d)
      expect(manager.resolve(:ctrl_d, active_contexts: [:chat])).to be_nil
    end

    it 'does not raise when key is not registered' do
      expect { manager.unbind(:nonexistent) }.not_to raise_error
    end
  end

  describe '#list' do
    it 'returns an array of binding hashes' do
      list = manager.list
      expect(list).to be_an(Array)
      expect(list.first.keys).to match_array(%i[key action contexts description])
    end

    it 'includes all default bindings' do
      keys = manager.list.map { |b| b[:key] }
      expect(keys).to include(:ctrl_d, :ctrl_k, :ctrl_s, :ctrl_l, :escape, :tab, :ctrl_c)
    end
  end

  describe '#load_defaults' do
    it 'resets bindings to defaults' do
      manager.bind(:ctrl_d, action: :custom, contexts: [:global])
      manager.load_defaults
      expect(manager.resolve(:ctrl_d, active_contexts: [:chat])).to eq(:toggle_dashboard)
    end

    it 'removes user-added bindings' do
      manager.bind(:ctrl_r, action: :reload, contexts: [:chat])
      manager.load_defaults
      expect(manager.resolve(:ctrl_r, active_contexts: [:chat])).to be_nil
    end
  end

  describe '#load_user_overrides' do
    it 'overrides bindings from the JSON file' do
      overrides = {
        ctrl_d: { action: 'my_action', contexts: ['global'], description: 'My override' }
      }
      File.write(overrides_path, Legion::JSON.generate(overrides))
      manager.load_user_overrides
      expect(manager.resolve(:ctrl_d, active_contexts: [:global])).to eq(:my_action)
    end

    it 'adds new bindings from the JSON file' do
      overrides = {
        ctrl_r: { action: 'reload_config', contexts: ['config'], description: 'Reload config' }
      }
      File.write(overrides_path, Legion::JSON.generate(overrides))
      manager.load_user_overrides
      expect(manager.resolve(:ctrl_r, active_contexts: [:config])).to eq(:reload_config)
    end

    it 'does not raise on missing overrides file' do
      expect { manager.load_user_overrides }.not_to raise_error
    end

    it 'skips entries without an action key' do
      overrides = { ctrl_d: { contexts: ['global'] } }
      File.write(overrides_path, Legion::JSON.generate(overrides))
      expect { manager.load_user_overrides }.not_to raise_error
    end

    it 'does not raise on malformed JSON' do
      File.write(overrides_path, 'not valid json {{')
      expect { manager.load_user_overrides }.not_to raise_error
    end
  end

  describe 'OVERRIDES_PATH constant' do
    it 'points to ~/.legionio/keybindings.json' do
      expect(described_class::OVERRIDES_PATH).to eq(File.expand_path('~/.legionio/keybindings.json'))
    end
  end
end
