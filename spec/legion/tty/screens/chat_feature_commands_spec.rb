# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'feature commands' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:sm) { double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil, show_overlay: nil) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude', name: 'Jane' },
                    llm_chat: nil,
                    screen_manager: sm,
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

  # ---------------------------------------------------------------------------
  # Feature 1: /help overlay
  # ---------------------------------------------------------------------------
  describe '/help as overlay' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/help')
    end

    it 'returns :handled' do
      allow(sm).to receive(:show_overlay)
      result = chat.handle_slash_command('/help')
      expect(result).to eq(:handled)
    end

    it 'calls screen_manager.show_overlay when screen_manager is available' do
      expect(sm).to receive(:show_overlay).with(a_kind_of(String))
      chat.handle_slash_command('/help')
    end

    it 'overlay text includes SESSION category' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('SESSION')
    end

    it 'overlay text includes CHAT category' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('CHAT')
    end

    it 'overlay text includes LLM category' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('LLM')
    end

    it 'overlay text includes NAVIGATION category' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('NAV')
    end

    it 'overlay text includes DISPLAY category' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('DISPLAY')
    end

    it 'overlay text includes TOOLS category' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('TOOLS')
    end

    it 'overlay text includes /save' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('/save')
    end

    it 'overlay text includes hotkey hint' do
      overlay_text = nil
      allow(sm).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('Ctrl+K')
    end

    it 'falls back to system message when screen_manager is unavailable' do
      allow(app).to receive(:respond_to?).with(:screen_manager).and_return(false)
      chat.handle_slash_command('/help')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('SESSION')
    end
  end

  # ---------------------------------------------------------------------------
  # Feature 2: message_count in status bar
  # ---------------------------------------------------------------------------
  describe 'message_count in status bar' do
    it 'updates message_count after activate' do
      chat.activate
      state = chat.status_bar.instance_variable_get(:@state)
      expect(state[:message_count]).to be > 0
    end

    it 'updates message_count after handle_user_message' do
      chat.activate
      allow(chat).to receive(:send_to_llm)
      allow(chat).to receive(:render_screen)
      before_count = chat.message_stream.messages.size
      chat.handle_user_message('hello')
      state = chat.status_bar.instance_variable_get(:@state)
      expect(state[:message_count]).to be > before_count
    end

    it 'renders N msgs in status bar when message_count is positive' do
      chat.status_bar.update(message_count: 5)
      rendered = chat.status_bar.render(width: 200)
      expect(rendered).to include('5 msgs')
    end

    it 'omits N msgs when message_count is zero' do
      chat.status_bar.update(message_count: 0)
      rendered = chat.status_bar.render(width: 200)
      expect(rendered).not_to include('msgs')
    end

    it 'message_count_segment returns nil when count is 0' do
      chat.status_bar.update(message_count: 0)
      expect(chat.status_bar.send(:message_count_segment)).to be_nil
    end

    it 'message_count_segment returns a string when count is positive' do
      chat.status_bar.update(message_count: 3)
      segment = chat.status_bar.send(:message_count_segment)
      expect(segment).to be_a(String)
      expect(segment).to include('3')
    end
  end

  # ---------------------------------------------------------------------------
  # Feature 3: /welcome command
  # ---------------------------------------------------------------------------
  describe '/welcome' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/welcome')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/welcome')
      expect(result).to eq(:handled)
    end

    it 'adds a system message with welcome text' do
      chat.handle_slash_command('/welcome')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Welcome')
    end

    it 'includes the configured name in the welcome message' do
      chat.handle_slash_command('/welcome')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Jane')
    end

    it 'mentions /help in the welcome message' do
      chat.handle_slash_command('/welcome')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('/help')
    end

    it 'can be called multiple times' do
      chat.handle_slash_command('/welcome')
      chat.handle_slash_command('/welcome')
      system_msgs = chat.message_stream.messages.select { |m| m[:role] == :system && m[:content].include?('Welcome') }
      expect(system_msgs.size).to be >= 2
    end

    it 'works after /clear' do
      chat.handle_slash_command('/clear')
      result = chat.handle_slash_command('/welcome')
      expect(result).to eq(:handled)
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Welcome')
    end
  end

  # ---------------------------------------------------------------------------
  # Feature 4: /tips command
  # ---------------------------------------------------------------------------
  describe '/tips' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/tips')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/tips')
      expect(result).to eq(:handled)
    end

    it 'adds a system message prefixed with Tip:' do
      chat.handle_slash_command('/tips')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to start_with('Tip:')
    end

    it 'shows a non-empty tip' do
      chat.handle_slash_command('/tips')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content].length).to be > 5
    end

    it 'TIPS constant has at least 15 entries' do
      expect(described_class::UiCommands::TIPS.size).to be >= 15
    end

    it 'TIPS constant contains strings' do
      expect(described_class::UiCommands::TIPS).to all(be_a(String))
    end

    it 'tip content comes from the TIPS constant' do
      tips = described_class::UiCommands::TIPS
      chat.handle_slash_command('/tips')
      msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      tip_content = msgs.last[:content].sub(/^Tip: /, '')
      expect(tips).to include(tip_content)
    end

    it 'can be called multiple times' do
      3.times { chat.handle_slash_command('/tips') }
      tip_msgs = chat.message_stream.messages.select { |m| m[:role] == :system && m[:content].start_with?('Tip:') }
      expect(tip_msgs.size).to eq(3)
    end
  end
end
