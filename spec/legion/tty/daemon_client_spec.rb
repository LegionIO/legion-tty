# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'

RSpec.describe Legion::TTY::DaemonClient do
  let(:cache_dir) { Dir.mktmpdir('legion-tty') }
  let(:cache_file) { File.join(cache_dir, 'catalog.json') }

  before do
    described_class.reset!
    described_class.configure(
      daemon_url: 'http://127.0.0.1:4567',
      cache_file: cache_file,
      timeout: 2
    )
  end

  after { FileUtils.rm_rf(cache_dir) }

  describe '.available?' do
    it 'returns false when daemon is not reachable' do
      expect(described_class.available?).to be false
    end
  end

  describe '.cached_manifest' do
    it 'returns nil when no cache file exists' do
      expect(described_class.cached_manifest).to be_nil
    end

    it 'returns parsed manifest when cache file exists' do
      File.write(cache_file, JSON.dump([{ name: 'lex-detect', state: 'running' }]))
      manifest = described_class.cached_manifest
      expect(manifest).to be_an(Array)
      expect(manifest.first[:name]).to eq('lex-detect')
    end
  end

  describe '.match_intent' do
    before do
      described_class.instance_variable_set(:@manifest, [
        {
          name: 'lex-tfe',
          state: 'running',
          known_intents: [
            { intent: 'list tfe workspaces', tool_chain: ['lex-tfe.workspaces.list'], confidence: 0.92 }
          ]
        }
      ])
    end

    it 'matches an exact intent' do
      match = described_class.match_intent('list tfe workspaces')
      expect(match).not_to be_nil
      expect(match[:confidence]).to eq(0.92)
    end

    it 'returns nil for unmatched intents' do
      expect(described_class.match_intent('do something random')).to be_nil
    end
  end

  describe '.chat' do
    it 'returns nil when daemon is unavailable' do
      result = described_class.chat(message: 'hello')
      expect(result).to be_nil
    end
  end
end
