# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'legion/tty/background/bootstrap_config'

RSpec.describe Legion::TTY::Background::BootstrapConfig do
  subject(:probe) { described_class.new }

  let(:settings_dir) { Dir.mktmpdir }

  before do
    stub_const('Legion::TTY::Background::BootstrapConfig::SETTINGS_DIR', settings_dir)
  end

  after { FileUtils.remove_entry(settings_dir) }

  describe '#run_async' do
    context 'when LEGIONIO_BOOTSTRAP_CONFIG is not set' do
      before { allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return(nil) }

      it 'pushes bootstrap_complete with nil data' do
        queue = Queue.new
        thread = probe.run_async(queue)
        thread.join(5)
        event = queue.pop(true)
        expect(event[:type]).to eq(:bootstrap_complete)
        expect(event[:data]).to be_nil
      end
    end

    context 'when LEGIONIO_BOOTSTRAP_CONFIG points to a local file' do
      let(:config) do
        {
          crypt: { vault: { enabled: true, clusters: {} } },
          transport: { connection: { host: '127.0.0.1' } },
          cache: { driver: 'dalli' }
        }
      end
      let(:config_file) { File.join(settings_dir, 'bootstrap.json') }

      before do
        File.write(config_file, config.to_json)
        allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return(config_file)
      end

      it 'writes split config files' do
        queue = Queue.new
        thread = probe.run_async(queue)
        thread.join(5)
        event = queue.pop(true)
        expect(event[:type]).to eq(:bootstrap_complete)
        expect(event[:data][:sections]).to contain_exactly('crypt', 'transport', 'cache')
        expect(event[:data][:files]).to contain_exactly('crypt.json', 'transport.json', 'cache.json')
      end

      it 'creates individual JSON files in settings dir' do
        queue = Queue.new
        probe.run_async(queue).join(5)
        queue.pop(true)

        crypt = JSON.parse(File.read(File.join(settings_dir, 'crypt.json')), symbolize_names: true)
        expect(crypt[:crypt][:vault][:enabled]).to be true

        transport = JSON.parse(File.read(File.join(settings_dir, 'transport.json')), symbolize_names: true)
        expect(transport[:transport][:connection][:host]).to eq('127.0.0.1')

        cache = JSON.parse(File.read(File.join(settings_dir, 'cache.json')), symbolize_names: true)
        expect(cache[:cache][:driver]).to eq('dalli')
      end
    end

    context 'when source is base64-encoded JSON' do
      let(:config) { { crypt: { vault: { enabled: false } } } }
      let(:config_file) { File.join(settings_dir, 'encoded.txt') }

      before do
        encoded = Base64.encode64(config.to_json)
        File.write(config_file, encoded)
        allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return(config_file)
      end

      it 'decodes and writes the config' do
        queue = Queue.new
        probe.run_async(queue).join(5)
        event = queue.pop(true)
        expect(event[:type]).to eq(:bootstrap_complete)
        expect(event[:data][:sections]).to eq(['crypt'])
      end
    end

    context 'when existing config files are present' do
      let(:config) { { crypt: { vault: { clusters: { dev: { address: 'vault-dev.example.com' } } } } } }
      let(:config_file) { File.join(settings_dir, 'bootstrap.json') }

      before do
        existing = { crypt: { jwt: { enabled: true } } }
        File.write(File.join(settings_dir, 'crypt.json'), JSON.pretty_generate(existing))
        File.write(config_file, config.to_json)
        allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return(config_file)
      end

      it 'deep merges with existing config' do
        queue = Queue.new
        probe.run_async(queue).join(5)
        queue.pop(true)

        merged = JSON.parse(File.read(File.join(settings_dir, 'crypt.json')), symbolize_names: true)
        expect(merged[:crypt][:jwt][:enabled]).to be true
        expect(merged[:crypt][:vault][:clusters][:dev][:address]).to eq('vault-dev.example.com')
      end
    end

    context 'when source file does not exist' do
      before do
        allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return('/nonexistent/file.json')
      end

      it 'pushes a bootstrap_error event' do
        queue = Queue.new
        probe.run_async(queue).join(5)
        event = queue.pop(true)
        expect(event[:type]).to eq(:bootstrap_error)
        expect(event[:error]).to include('File not found')
      end
    end

    context 'when source contains invalid JSON' do
      let(:config_file) { File.join(settings_dir, 'bad.txt') }

      before do
        File.write(config_file, 'not json at all')
        allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return(config_file)
      end

      it 'pushes a bootstrap_error event' do
        queue = Queue.new
        probe.run_async(queue).join(5)
        event = queue.pop(true)
        expect(event[:type]).to eq(:bootstrap_error)
      end
    end

    context 'when config has non-hash values' do
      let(:config) { { crypt: { vault: { enabled: true } }, version: '1.0' } }
      let(:config_file) { File.join(settings_dir, 'mixed.json') }

      before do
        File.write(config_file, config.to_json)
        allow(ENV).to receive(:fetch).with('LEGIONIO_BOOTSTRAP_CONFIG', nil).and_return(config_file)
      end

      it 'only writes hash values as split files' do
        queue = Queue.new
        probe.run_async(queue).join(5)
        event = queue.pop(true)
        expect(event[:data][:files]).to eq(['crypt.json'])
        expect(File.exist?(File.join(settings_dir, 'version.json'))).to be false
      end
    end
  end
end
