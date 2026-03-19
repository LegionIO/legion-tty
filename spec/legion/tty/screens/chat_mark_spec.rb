# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/mark command' do
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
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(false)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe '/mark' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/mark')
    end

    it 'returns :handled when given a label' do
      expect(chat.handle_slash_command('/mark intro')).to eq(:handled)
    end

    it 'inserts a marker message formatted as --- label ---' do
      chat.handle_slash_command('/mark intro')
      msg = chat.message_stream.messages.find { |m| m[:marker] == 'intro' }
      expect(msg).not_to be_nil
      expect(msg[:content]).to eq('--- intro ---')
    end

    it 'stores the label in the :marker key of the message' do
      chat.handle_slash_command('/mark section_one')
      msg = chat.message_stream.messages.find { |m| m[:marker] }
      expect(msg[:marker]).to eq('section_one')
    end

    it 'adds the marker message with role :system' do
      chat.handle_slash_command('/mark checkpoint')
      msg = chat.message_stream.messages.find { |m| m[:marker] == 'checkpoint' }
      expect(msg[:role]).to eq(:system)
    end

    it 'returns :handled with no args and lists markers' do
      chat.handle_slash_command('/mark start')
      expect(chat.handle_slash_command('/mark')).to eq(:handled)
    end

    it 'lists all markers with indices when called with no args' do
      chat.handle_slash_command('/mark start')
      chat.handle_slash_command('/mark middle')
      chat.handle_slash_command('/mark')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('--- start ---')
      expect(content).to include('--- middle ---')
    end

    it 'shows "No markers set." when no markers exist' do
      chat.handle_slash_command('/mark')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No markers set.')
    end

    it 'supports multiple distinct markers' do
      chat.handle_slash_command('/mark alpha')
      chat.handle_slash_command('/mark beta')
      markers = chat.message_stream.messages.select { |m| m[:marker] }
      expect(markers.map { |m| m[:marker] }).to contain_exactly('alpha', 'beta')
    end
  end
end
