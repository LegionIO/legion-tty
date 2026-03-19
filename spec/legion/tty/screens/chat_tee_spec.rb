# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/tee command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil,
                                                 show_overlay: nil),
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

  describe '/tee in SLASH_COMMANDS' do
    it 'includes /tee in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/tee')
    end
  end

  describe '/tee with no args' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/tee')).to eq(:handled)
    end

    it 'reports inactive when tee is off' do
      chat.handle_slash_command('/tee')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('inactive')
    end

    it 'reports active path when tee is on' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.txt')
        chat.handle_slash_command("/tee #{path}")
        chat.handle_slash_command('/tee')
        content = chat.message_stream.messages.last[:content]
        expect(content).to include(path)
      end
    end
  end

  describe '/tee <path>' do
    it 'returns :handled' do
      Dir.mktmpdir do |dir|
        expect(chat.handle_slash_command("/tee #{File.join(dir, 'out.txt')}")).to eq(:handled)
      end
    end

    it 'sets @tee_path to the expanded path' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.txt')
        chat.handle_slash_command("/tee #{path}")
        content = chat.message_stream.messages.last[:content]
        expect(content).to include('Tee started')
        expect(content).to include(path)
      end
    end

    it 'appends user messages to the tee file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.txt')
        chat.handle_slash_command("/tee #{path}")
        chat.send(:tee_message, '[user] hello world')
        content = File.read(path)
        expect(content).to include('hello world')
      end
    end

    it 'appends multiple lines to the tee file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.txt')
        chat.handle_slash_command("/tee #{path}")
        chat.send(:tee_message, '[user] first')
        chat.send(:tee_message, '[assistant] second')
        content = File.read(path)
        expect(content).to include('first')
        expect(content).to include('second')
      end
    end
  end

  describe '/tee off' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/tee off')).to eq(:handled)
    end

    it 'clears @tee_path' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.txt')
        chat.handle_slash_command("/tee #{path}")
        chat.handle_slash_command('/tee off')
        content = chat.message_stream.messages.last[:content]
        expect(content).to include('stopped')
      end
    end

    it 'stops writing to file after /tee off' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.txt')
        chat.handle_slash_command("/tee #{path}")
        chat.send(:tee_message, '[user] before off')
        chat.handle_slash_command('/tee off')
        chat.send(:tee_message, '[user] after off')
        content = File.read(path)
        expect(content).to include('before off')
        expect(content).not_to include('after off')
      end
    end
  end

  describe 'tee_message helper' do
    it 'is a no-op when @tee_path is nil' do
      expect { chat.send(:tee_message, 'anything') }.not_to raise_error
    end

    it 'does not raise on file write errors' do
      chat.instance_variable_set(:@tee_path, '/nonexistent/deep/path/out.txt')
      expect { chat.send(:tee_message, 'line') }.not_to raise_error
    end
  end
end
