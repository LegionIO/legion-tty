# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/archive and /archives commands' do
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

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe 'SLASH_COMMANDS' do
    it 'includes /archive' do
      expect(described_class::SLASH_COMMANDS).to include('/archive')
    end

    it 'includes /archives' do
      expect(described_class::SLASH_COMMANDS).to include('/archives')
    end
  end

  describe '/archive' do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    before do
      allow(File).to receive(:expand_path).and_call_original
      allow(File).to receive(:expand_path).with('~/.legionio/archives').and_return(tmpdir)
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/archive myarchive')
      expect(result).to eq(:handled)
    end

    it 'saves messages to archives directory with given name' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.handle_slash_command('/archive myarchive')
      expect(File.exist?(File.join(tmpdir, 'myarchive.json'))).to be true
    end

    it 'writes messages as JSON' do
      chat.message_stream.add_message(role: :user, content: 'test message')
      chat.handle_slash_command('/archive testarchive')
      raw = File.read(File.join(tmpdir, 'testarchive.json'))
      data = JSON.parse(raw, symbolize_names: true)
      expect(data[:name]).to eq('testarchive')
      expect(data[:messages]).to be_an(Array)
    end

    it 'clears messages after archiving' do
      chat.message_stream.add_message(role: :user, content: 'will be archived')
      chat.handle_slash_command('/archive myarchive')
      system_msgs, non_system = chat.message_stream.messages.partition { |m| m[:role] == :system }
      expect(non_system).to be_empty
      expect(system_msgs.last[:content]).to include('archived as')
    end

    it 'shows confirmation with archive name' do
      chat.handle_slash_command('/archive named-archive')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('named-archive')
    end

    it 'notifies status bar' do
      expect(chat.status_bar).to receive(:notify).with(hash_including(level: :success))
      chat.handle_slash_command('/archive myarchive')
    end

    it 'auto-generates name when no argument given' do
      chat.instance_variable_set(:@session_name, 'mysession')
      chat.handle_slash_command('/archive')
      files = Dir.glob(File.join(tmpdir, '*.json'))
      expect(files).not_to be_empty
      expect(File.basename(files.first)).to match(/\Amysession-\d{8}-\d{6}\.json\z/)
    end

    it 'creates the archives directory if it does not exist' do
      subdir = File.join(tmpdir, 'new-archives')
      allow(File).to receive(:expand_path).with('~/.legionio/archives').and_return(subdir)
      chat.handle_slash_command('/archive myarchive')
      expect(Dir.exist?(subdir)).to be true
    end
  end

  describe '/archives' do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmpdir) }

    before do
      allow(File).to receive(:expand_path).and_call_original
      allow(File).to receive(:expand_path).with('~/.legionio/archives').and_return(tmpdir)
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/archives')).to eq(:handled)
    end

    it 'shows "No archives found." when directory is empty' do
      chat.handle_slash_command('/archives')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No archives found.')
    end

    it 'lists archived sessions by name' do
      File.write(File.join(tmpdir, 'session-one.json'), '{}')
      File.write(File.join(tmpdir, 'session-two.json'), '{}')
      chat.handle_slash_command('/archives')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      content = msgs.last[:content]
      expect(content).to include('session-one')
      expect(content).to include('session-two')
    end

    it 'shows file sizes' do
      File.write(File.join(tmpdir, 'my-archive.json'), '{"messages":[]}')
      chat.handle_slash_command('/archives')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('bytes')
    end
  end
end
