# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/hotkeys'

RSpec.describe Legion::TTY::Hotkeys do
  subject(:hotkeys) { described_class.new }

  describe '#register and #handle' do
    it 'triggers the callback for a registered key' do
      triggered = false
      hotkeys.register('q', 'quit') { triggered = true }
      hotkeys.handle('q')
      expect(triggered).to be true
    end

    it 'returns true when a registered key is handled' do
      hotkeys.register('q', 'quit') { nil }
      expect(hotkeys.handle('q')).to be true
    end

    it 'passes the registered callback return value through' do
      hotkeys.register('r', 'reload') { :reloaded }
      hotkeys.handle('r')
    end
  end

  describe '#handle' do
    it 'returns false for an unregistered key' do
      expect(hotkeys.handle('z')).to be false
    end

    it 'does not raise for unknown keys' do
      expect { hotkeys.handle(:f9) }.not_to raise_error
    end
  end

  describe '#list' do
    it 'returns an empty array when no hotkeys are registered' do
      expect(hotkeys.list).to eq([])
    end

    it 'lists registered hotkeys with key and description' do
      hotkeys.register('q', 'quit') { nil }
      hotkeys.register('h', 'help') { nil }
      listed = hotkeys.list
      expect(listed).to include({ key: 'q', description: 'quit' })
      expect(listed).to include({ key: 'h', description: 'help' })
    end

    it 'list entries contain only key and description keys' do
      hotkeys.register('q', 'quit') { nil }
      entry = hotkeys.list.first
      expect(entry.keys).to match_array(%i[key description])
    end
  end
end
