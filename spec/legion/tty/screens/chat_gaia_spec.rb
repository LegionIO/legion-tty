# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/gaia command' do
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

  describe '/gaia' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/gaia')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/gaia')).to eq(:handled)
    end

    context 'when Gaia NotificationGate is not defined' do
      it 'shows not-available message' do
        chat.handle_slash_command('/gaia')
        sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(sys_msgs.last[:content]).to include('not available')
      end
    end

    context 'when Gaia NotificationGate is available' do
      let(:gate_instance) { double('gate_instance') }

      before do
        gate = gate_instance
        gate_mod = Module.new
        gate_mod.define_singleton_method(:instance) { gate }
        stub_const('Legion::Gaia::NotificationGate', gate_mod)
        allow(gate_instance).to receive(:respond_to?).and_return(false)
      end

      it 'shows Gaia NotificationGate header' do
        chat.handle_slash_command('/gaia')
        sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(sys_msgs.last[:content]).to include('Gaia NotificationGate')
      end

      it 'shows presence info when presence_evaluator is available' do
        pe = double('pe', availability: 'Available', updated_at: Time.now.utc)
        allow(gate_instance).to receive(:respond_to?).with(:presence_evaluator).and_return(true)
        allow(gate_instance).to receive(:presence_evaluator).and_return(pe)
        chat.handle_slash_command('/gaia')
        sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(sys_msgs.last[:content]).to include('Presence')
        expect(sys_msgs.last[:content]).to include('Available')
      end
    end

    context '/gaia presence subcommand' do
      before do
        allow(Legion::TTY::NotificationGate).to receive(:update_presence)
      end

      it 'calls NotificationGate.update_presence with the given status' do
        chat.handle_slash_command('/gaia presence DoNotDisturb')
        expect(Legion::TTY::NotificationGate).to have_received(:update_presence).with(availability: 'DoNotDisturb')
      end

      it 'shows a confirmation message' do
        chat.handle_slash_command('/gaia presence Busy')
        sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(sys_msgs.last[:content]).to include('Presence set to: Busy')
      end

      it 'shows usage when no status is provided' do
        chat.handle_slash_command('/gaia presence')
        sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(sys_msgs.last[:content]).to include('Usage:')
        expect(sys_msgs.last[:content]).to include('Valid:')
      end

      it 'shows usage when status is blank' do
        chat.handle_slash_command('/gaia presence   ')
        sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(sys_msgs.last[:content]).to include('Usage:')
      end

      it 'returns :handled' do
        expect(chat.handle_slash_command('/gaia presence Available')).to eq(:handled)
      end
    end
  end
end
