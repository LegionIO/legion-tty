# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

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
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      expect(described_class.available?).to be false
    end
  end

  describe '.cached_manifest' do
    it 'returns nil when no cache file exists' do
      expect(described_class.cached_manifest).to be_nil
    end

    it 'returns parsed manifest when cache file exists' do
      File.write(cache_file, Legion::JSON.dump([{ name: 'lex-detect', state: 'running' }]))
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
                                                  { intent: 'list tfe workspaces',
                                                    tool_chain: ['lex-tfe.workspaces.list'], confidence: 0.92 }
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
      # Simulate an unreachable daemon rather than relying on nothing listening
      # on 127.0.0.1:4567 — a real LegionIO daemon may be running locally.
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      result = described_class.chat(message: 'hello')
      expect(result).to be_nil
    end
  end

  describe '.run_tool' do
    let(:ok_response) do
      instance_double(Net::HTTPResponse,
                      code: '200',
                      body: Legion::JSON.dump({ data: { result: 'tool output' } }))
    end

    let(:error_response) do
      instance_double(Net::HTTPResponse,
                      code: '422',
                      body: Legion::JSON.dump({ error: 'unprocessable' }))
    end

    context 'on a 200 response' do
      before do
        allow(Net::HTTP).to receive(:start).and_yield(
          double('http', request: ok_response)
        )
      end

      it 'returns status :ok' do
        result = described_class.run_tool(name: 'legion.search', args: { query: 'test' })
        expect(result[:status]).to eq(:ok)
      end

      it 'includes data in the result' do
        result = described_class.run_tool(name: 'legion.search', args: {})
        expect(result[:data]).to be_a(Hash)
      end
    end

    context 'on a 422 response' do
      before do
        allow(Net::HTTP).to receive(:start).and_yield(
          double('http', request: error_response)
        )
      end

      it 'returns status :error' do
        result = described_class.run_tool(name: 'legion.search', args: {})
        expect(result[:status]).to eq(:error)
      end

      it 'includes the HTTP status code in the error' do
        result = described_class.run_tool(name: 'legion.search', args: {})
        expect(result[:error]).to include('422')
      end
    end

    context 'when a StandardError is raised' do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it 'returns status :unavailable' do
        result = described_class.run_tool(name: 'legion.search', args: {})
        expect(result[:status]).to eq(:unavailable)
      end

      it 'does not raise' do
        expect { described_class.run_tool(name: 'legion.search') }.not_to raise_error
      end
    end
  end
end
