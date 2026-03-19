# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/multiline command' do
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
    it 'includes /multiline' do
      expect(described_class::SLASH_COMMANDS).to include('/multiline')
    end
  end

  describe '/multiline toggle' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/multiline')).to eq(:handled)
    end

    it 'starts with multiline_mode false' do
      expect(chat.instance_variable_get(:@multiline_mode)).to be false
    end

    it 'toggles multiline_mode to true on first call' do
      chat.handle_slash_command('/multiline')
      expect(chat.instance_variable_get(:@multiline_mode)).to be true
    end

    it 'toggles multiline_mode back to false on second call' do
      chat.handle_slash_command('/multiline')
      chat.handle_slash_command('/multiline')
      expect(chat.instance_variable_get(:@multiline_mode)).to be false
    end

    it 'shows "Multi-line mode ON" message when enabling' do
      chat.handle_slash_command('/multiline')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Multi-line mode ON')
    end

    it 'shows "Multi-line mode OFF" message when disabling' do
      chat.handle_slash_command('/multiline')
      chat.handle_slash_command('/multiline')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Multi-line mode OFF')
    end

    it 'shows "Submit with empty line" hint when enabling' do
      chat.handle_slash_command('/multiline')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('Submit with empty line')
    end

    it 'calls status_bar.update with multiline: true when enabling' do
      expect(chat.status_bar).to receive(:update).with(hash_including(multiline: true))
      chat.handle_slash_command('/multiline')
    end

    it 'calls status_bar.update with multiline: false when disabling' do
      chat.instance_variable_set(:@multiline_mode, true)
      expect(chat.status_bar).to receive(:update).with(hash_including(multiline: false))
      chat.handle_slash_command('/multiline')
    end
  end

  describe 'StatusBar [ML] indicator' do
    it 'shows [ML] when multiline is true' do
      chat.status_bar.update(multiline: true)
      expect(chat.status_bar.render(width: 200)).to include('[ML]')
    end

    it 'omits [ML] when multiline is false' do
      chat.status_bar.update(multiline: false)
      expect(chat.status_bar.render(width: 200)).not_to include('[ML]')
    end

    it 'omits [ML] by default' do
      expect(chat.status_bar.render(width: 200)).not_to include('[ML]')
    end
  end

  describe '#debug_segment includes multiline state' do
    it 'includes multiline:false in debug segment when disabled' do
      chat.instance_variable_set(:@debug_mode, true)
      expect(chat.send(:debug_segment)).to include('multiline:false')
    end

    it 'includes multiline:true in debug segment when enabled' do
      chat.instance_variable_set(:@debug_mode, true)
      chat.instance_variable_set(:@multiline_mode, true)
      expect(chat.send(:debug_segment)).to include('multiline:true')
    end
  end

  describe '#read_multiline_input' do
    it 'collects multiple lines until empty line and joins with newline' do
      allow(reader).to receive(:read_line).and_return('line one', 'line two', '', nil)
      chat.instance_variable_set(:@multiline_mode, true)
      result = chat.send(:read_multiline_input)
      expect(result).to eq("line one\nline two")
    end

    it 'returns nil when first read returns nil (Ctrl+C/EOF)' do
      allow(reader).to receive(:read_line).and_return(nil)
      result = chat.send(:read_multiline_input)
      expect(result).to be_nil
    end

    it 'returns nil when only an empty line is entered' do
      allow(reader).to receive(:read_line).and_return('')
      result = chat.send(:read_multiline_input)
      expect(result).to be_nil
    end

    it 'collects a single non-empty line before empty terminator' do
      allow(reader).to receive(:read_line).and_return('hello', '')
      result = chat.send(:read_multiline_input)
      expect(result).to eq('hello')
    end

    it 'returns nil on Interrupt' do
      allow(reader).to receive(:read_line).and_raise(Interrupt)
      result = chat.send(:read_multiline_input)
      expect(result).to be_nil
    end
  end

  describe '#read_input routing' do
    it 'calls read_multiline_input when multiline_mode is on' do
      chat.instance_variable_set(:@multiline_mode, true)
      expect(chat).to receive(:read_multiline_input).and_return('multi')
      expect(chat.send(:read_input)).to eq('multi')
    end

    it 'calls input_bar.read_line normally when multiline_mode is off' do
      allow(reader).to receive(:read_line).and_return('normal')
      expect(chat.send(:read_input)).to eq('normal')
    end
  end
end
