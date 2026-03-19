# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/speak command' do
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
    it 'includes /speak' do
      expect(described_class::SLASH_COMMANDS).to include('/speak')
    end
  end

  describe '/speak initializes to false' do
    it 'starts with speak_mode false' do
      expect(chat.instance_variable_get(:@speak_mode)).to be false
    end
  end

  describe '/speak on non-macOS' do
    before { stub_const('RUBY_PLATFORM', 'x86_64-linux') }

    it 'returns :handled' do
      expect(chat.handle_slash_command('/speak')).to eq(:handled)
    end

    it 'shows macOS-only message' do
      chat.handle_slash_command('/speak')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('macOS')
    end

    it 'does not change speak_mode' do
      chat.handle_slash_command('/speak')
      expect(chat.instance_variable_get(:@speak_mode)).to be false
    end
  end

  describe '/speak on macOS' do
    before { stub_const('RUBY_PLATFORM', 'arm64-darwin23') }

    it 'returns :handled with no arg (toggle)' do
      expect(chat.handle_slash_command('/speak')).to eq(:handled)
    end

    it 'toggles speak_mode on with no arg' do
      chat.handle_slash_command('/speak')
      expect(chat.instance_variable_get(:@speak_mode)).to be true
    end

    it 'toggles speak_mode off on second call' do
      chat.handle_slash_command('/speak')
      chat.handle_slash_command('/speak')
      expect(chat.instance_variable_get(:@speak_mode)).to be false
    end

    it 'enables speak_mode with /speak on' do
      chat.handle_slash_command('/speak on')
      expect(chat.instance_variable_get(:@speak_mode)).to be true
    end

    it 'disables speak_mode with /speak off' do
      chat.instance_variable_set(:@speak_mode, true)
      chat.handle_slash_command('/speak off')
      expect(chat.instance_variable_get(:@speak_mode)).to be false
    end

    it 'shows ON message when enabling via toggle' do
      chat.handle_slash_command('/speak')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('ON')
    end

    it 'shows OFF message when disabling via toggle' do
      chat.instance_variable_set(:@speak_mode, true)
      chat.handle_slash_command('/speak')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include('OFF')
    end
  end

  describe '#speak_response' do
    context 'on macOS' do
      before { stub_const('RUBY_PLATFORM', 'arm64-darwin23') }

      it 'spawns say command' do
        expect(Process).to receive(:spawn).with('say', anything, err: '/dev/null', out: '/dev/null')
        chat.send(:speak_response, 'hello world')
      end

      it 'truncates text to 500 chars' do
        long_text = 'a' * 600
        expect(Process).to receive(:spawn) do |*args|
          expect(args[1].length).to be <= 501
        end
        chat.send(:speak_response, long_text)
      end

      it 'rescues StandardError silently' do
        allow(Process).to receive(:spawn).and_raise(StandardError, 'spawn failed')
        expect { chat.send(:speak_response, 'test') }.not_to raise_error
      end
    end

    context 'on non-macOS' do
      before { stub_const('RUBY_PLATFORM', 'x86_64-linux') }

      it 'does not spawn say' do
        expect(Process).not_to receive(:spawn)
        chat.send(:speak_response, 'hello')
      end
    end
  end
end
