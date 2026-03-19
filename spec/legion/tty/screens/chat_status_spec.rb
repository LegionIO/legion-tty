# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/status command' do
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

  describe '/status' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/status')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/status')).to eq(:handled)
    end

    it 'adds a system message' do
      chat.handle_slash_command('/status')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last).not_to be_nil
    end

    it 'shows "Mode Status:" header' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('Mode Status:')
    end

    it 'shows plan mode as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Plan mode\s*:\s*off/)
    end

    it 'shows plan mode as on after /plan is toggled' do
      chat.handle_slash_command('/plan')
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Plan mode\s*:\s*on/)
    end

    it 'shows focus mode as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Focus mode\s*:\s*off/)
    end

    it 'shows debug mode as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Debug mode\s*:\s*off/)
    end

    it 'shows silent mode as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Silent mode\s*:\s*off/)
    end

    it 'shows mute system as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Mute system\s*:\s*off/)
    end

    it 'shows multi-line mode as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Multi-line\s*:\s*off/)
    end

    it 'shows autosave as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Autosave\s*:\s*off/)
    end

    it 'shows autosave interval when enabled' do
      chat.instance_variable_set(:@autosave_enabled, true)
      chat.instance_variable_set(:@autosave_interval, 30)
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Autosave\s*:.*30s/)
    end

    it 'shows personality as default when none set' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Personality\s*:\s*default/)
    end

    it 'shows the current theme' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Theme\s*:\s*\w+/)
    end

    it 'shows wrap as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Wrap\s*:\s*off/)
    end

    it 'shows truncate as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Truncate\s*:\s*off/)
    end

    it 'shows filter as none by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Filter\s*:\s*none/)
    end

    it 'shows tee as off by default' do
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to match(/Tee\s*:\s*off/)
    end

    it 'shows tee path when active' do
      chat.instance_variable_set(:@tee_path, '/tmp/tee_test.log')
      chat.handle_slash_command('/status')
      content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
      expect(content).to include('/tmp/tee_test.log')
    end
  end
end
