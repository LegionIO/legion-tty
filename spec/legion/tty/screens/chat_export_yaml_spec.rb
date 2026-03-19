# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Legion::TTY::Screens::Chat, 'YAML export' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil,
                                                 dismiss_overlay: nil, show_overlay: nil),
                    hotkeys: double('hk', list: []),
                    respond_to?: true)
  end

  before do
    allow(reader).to receive(:on)
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  describe '/export yaml' do
    it 'creates a YAML file' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'world')

      dir = Dir.mktmpdir
      allow(File).to receive(:expand_path).with('~/.legionio/exports').and_return(dir)
      result = chat.handle_slash_command('/export yaml')
      expect(result).to eq(:handled)

      files = Dir.glob(File.join(dir, '*.yaml'))
      expect(files).not_to be_empty
    ensure
      FileUtils.rm_rf(dir)
    end

    it 'creates a file that can be loaded back as YAML' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'world')

      dir = Dir.mktmpdir
      allow(File).to receive(:expand_path).with('~/.legionio/exports').and_return(dir)
      chat.handle_slash_command('/export yaml')

      file = Dir.glob(File.join(dir, '*.yaml')).first
      parsed = YAML.safe_load_file(file)
      expect(parsed).to be_a(Hash)
      expect(parsed['messages']).to be_an(Array)
    ensure
      FileUtils.rm_rf(dir)
    end

    it 'includes all message fields (role, content, timestamp)' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hello')

      dir = Dir.mktmpdir
      allow(File).to receive(:expand_path).with('~/.legionio/exports').and_return(dir)
      chat.handle_slash_command('/export yaml')

      file = Dir.glob(File.join(dir, '*.yaml')).first
      parsed = YAML.safe_load_file(file)
      msg = parsed['messages'].find { |m| m['role'] == 'user' }
      expect(msg).not_to be_nil
      expect(msg['content']).to eq('hello')
      expect(msg).to have_key('timestamp')
    ensure
      FileUtils.rm_rf(dir)
    end

    it 'includes exported_at timestamp at the top level' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'test')

      dir = Dir.mktmpdir
      allow(File).to receive(:expand_path).with('~/.legionio/exports').and_return(dir)
      chat.handle_slash_command('/export yaml')

      file = Dir.glob(File.join(dir, '*.yaml')).first
      parsed = YAML.safe_load_file(file)
      expect(parsed).to have_key('exported_at')
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
