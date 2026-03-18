# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/boot_logger'

RSpec.describe Legion::TTY::BootLogger do
  let(:tmpdir) { Dir.mktmpdir }
  let(:log_path) { File.join(tmpdir, 'test-boot.log') }
  subject(:logger) { described_class.new(path: log_path) }

  after { FileUtils.remove_entry(tmpdir) }

  describe '#initialize' do
    it 'creates the log file' do
      logger # trigger creation
      expect(File.exist?(log_path)).to be true
    end

    it 'creates parent directories' do
      nested = File.join(tmpdir, 'deep', 'nested', 'boot.log')
      described_class.new(path: nested)
      expect(File.exist?(nested)).to be true
    end

    it 'writes an initial boot message' do
      logger # trigger creation
      content = File.read(log_path)
      expect(content).to include('boot logger started')
    end
  end

  describe '#log' do
    it 'appends a timestamped line' do
      logger.log('test', 'hello world')
      content = File.read(log_path)
      expect(content).to include('[test] hello world')
    end

    it 'includes timestamp in HH:MM:SS.mmm format' do
      logger.log('src', 'msg')
      content = File.read(log_path)
      expect(content).to match(/\[\d{2}:\d{2}:\d{2}\.\d{3}\]/)
    end

    it 'appends multiple log entries' do
      logger.log('a', 'first')
      logger.log('b', 'second')
      lines = File.readlines(log_path)
      non_boot = lines.reject { |l| l.include?('boot logger started') }
      expect(non_boot.size).to eq(2)
    end
  end

  describe '#log_hash' do
    it 'logs a label and each key-value pair' do
      logger.log_hash('src', 'config', { name: 'test', port: 8080 })
      content = File.read(log_path)
      expect(content).to include('config:')
      expect(content).to include('name: "test"')
      expect(content).to include('port: 8080')
    end
  end

  describe '#path' do
    it 'returns the log file path' do
      expect(logger.path).to eq(log_path)
    end
  end
end
