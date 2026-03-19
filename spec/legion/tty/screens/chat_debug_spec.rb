# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/debug command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil),
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

  describe '/debug' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/debug')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/debug')).to eq(:handled)
    end

    it 'starts with debug_mode false' do
      expect(chat.instance_variable_get(:@debug_mode)).to be false
    end

    it 'toggles debug_mode to true on first call' do
      chat.handle_slash_command('/debug')
      expect(chat.instance_variable_get(:@debug_mode)).to be true
    end

    it 'toggles debug_mode back to false on second call' do
      chat.handle_slash_command('/debug')
      chat.handle_slash_command('/debug')
      expect(chat.instance_variable_get(:@debug_mode)).to be false
    end

    it 'shows "Debug mode ON" message when enabling' do
      chat.handle_slash_command('/debug')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Debug mode ON')
    end

    it 'shows "Debug mode OFF" message when disabling' do
      chat.handle_slash_command('/debug')
      chat.handle_slash_command('/debug')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Debug mode OFF')
    end

    it 'calls status_bar.update with debug_mode: true when enabling' do
      expect(chat.status_bar).to receive(:update).with(hash_including(debug_mode: true))
      chat.handle_slash_command('/debug')
    end

    it 'calls status_bar.update with debug_mode: false when disabling' do
      chat.instance_variable_set(:@debug_mode, true)
      expect(chat.status_bar).to receive(:update).with(hash_including(debug_mode: false))
      chat.handle_slash_command('/debug')
    end
  end

  describe '#debug_segment' do
    it 'returns nil when debug_mode is false' do
      expect(chat.send(:debug_segment)).to be_nil
    end

    it 'returns a string when debug_mode is true' do
      chat.instance_variable_set(:@debug_mode, true)
      expect(chat.send(:debug_segment)).to be_a(String)
    end

    it 'includes [DEBUG] prefix' do
      chat.instance_variable_set(:@debug_mode, true)
      expect(chat.send(:debug_segment)).to include('[DEBUG]')
    end

    it 'includes message count' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.message_stream.add_message(role: :user, content: 'hi')
      segment = chat.send(:debug_segment)
      expect(segment).to match(/msgs:\d+/)
    end

    it 'includes plan mode state' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.instance_variable_set(:@plan_mode, true)
      segment = chat.send(:debug_segment)
      expect(segment).to include('plan:true')
    end

    it 'includes personality' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.instance_variable_set(:@personality, 'concise')
      segment = chat.send(:debug_segment)
      expect(segment).to include('personality:concise')
    end

    it 'shows "default" personality when none set' do
      chat.instance_variable_set(:@debug_mode, true)
      segment = chat.send(:debug_segment)
      expect(segment).to include('personality:default')
    end

    it 'includes alias count' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.instance_variable_set(:@aliases, { '/h' => '/help' })
      segment = chat.send(:debug_segment)
      expect(segment).to include('aliases:1')
    end

    it 'includes snippet count' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.instance_variable_set(:@snippets, { 'mysnip' => 'content' })
      segment = chat.send(:debug_segment)
      expect(segment).to include('snippets:1')
    end

    it 'includes pinned count' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'pinned' }])
      segment = chat.send(:debug_segment)
      expect(segment).to include('pinned:1')
    end
  end

  describe '#render with debug mode' do
    it 'does not include debug line when debug_mode is false' do
      allow(chat.message_stream).to receive(:render).and_return([])
      allow(chat.message_stream).to receive(:scroll_position).and_return(nil)
      lines = chat.render(80, 24)
      debug_lines = lines.select { |l| l.is_a?(String) && l.include?('[DEBUG]') }
      expect(debug_lines).to be_empty
    end

    it 'includes debug line when debug_mode is true' do
      chat.instance_variable_set(:@debug_mode, true)
      allow(chat.message_stream).to receive(:render).and_return([])
      allow(chat.message_stream).to receive(:scroll_position).and_return(nil)
      lines = chat.render(80, 24)
      debug_lines = lines.select { |l| l.is_a?(String) && l.include?('[DEBUG]') }
      expect(debug_lines).not_to be_empty
    end
  end

  describe 'StatusBar [DBG] indicator' do
    it 'status_bar shows [DBG] when debug_mode is set' do
      chat.status_bar.update(debug_mode: true)
      rendered = chat.status_bar.render(width: 200)
      expect(rendered).to include('[DBG]')
    end

    it 'status_bar does not show [DBG] when debug_mode is false' do
      rendered = chat.status_bar.render(width: 200)
      expect(rendered).not_to include('[DBG]')
    end
  end

  describe '/help mentions /debug' do
    it 'includes /debug in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/debug')
    end
  end
end
