# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'HTML export' do
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

  describe '/export html' do
    it 'creates an HTML file' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.message_stream.add_message(role: :assistant, content: 'world')

      dir = Dir.mktmpdir
      allow(File).to receive(:expand_path).with('~/.legionio/exports').and_return(dir)
      result = chat.handle_slash_command('/export html')
      expect(result).to eq(:handled)

      files = Dir.glob(File.join(dir, '*.html'))
      expect(files).not_to be_empty
      content = File.read(files.first)
      expect(content).to include('<!DOCTYPE html>')
      expect(content).to include('hello')
      expect(content).to include('world')
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  describe '#escape_html' do
    it 'escapes HTML special characters' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.send(:escape_html, '<script>alert("xss")</script>')
      expect(result).not_to include('<script>')
      expect(result).to include('&lt;script&gt;')
    end
  end
end
