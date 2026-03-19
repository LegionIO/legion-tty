# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/truncate command' do
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

  describe '/truncate' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/truncate')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/truncate 100')).to eq(:handled)
    end

    it 'sets truncation limit when given a number' do
      chat.handle_slash_command('/truncate 100')
      expect(chat.message_stream.truncate_limit).to eq(100)
    end

    it 'shows confirmation after setting a limit' do
      chat.handle_slash_command('/truncate 200')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Truncation set to 200 chars.')
    end

    it 'disables truncation with "off"' do
      chat.message_stream.truncate_limit = 100
      chat.handle_slash_command('/truncate off')
      expect(chat.message_stream.truncate_limit).to be_nil
    end

    it 'shows confirmation after disabling' do
      chat.handle_slash_command('/truncate off')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Truncation disabled.')
    end

    it 'shows "off" status when no truncation is set' do
      chat.handle_slash_command('/truncate')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Truncation: off')
    end

    it 'shows current limit in status when truncation is active' do
      chat.message_stream.truncate_limit = 150
      chat.handle_slash_command('/truncate')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Truncation: 150 chars')
    end

    it 'shows usage message for invalid (non-numeric, non-off) arg' do
      chat.handle_slash_command('/truncate abc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Usage: /truncate [N|off]')
    end

    it 'shows usage message for zero' do
      chat.handle_slash_command('/truncate 0')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Usage: /truncate [N|off]')
    end
  end
end

RSpec.describe Legion::TTY::Components::MessageStream, 'truncation rendering' do
  subject(:stream) { described_class.new }

  describe '#truncate_limit' do
    it 'initializes to nil (no truncation)' do
      expect(stream.truncate_limit).to be_nil
    end

    it 'can be set via attr_accessor' do
      stream.truncate_limit = 100
      expect(stream.truncate_limit).to eq(100)
    end
  end

  describe 'display truncation' do
    it 'truncates long assistant messages in display when limit is set' do
      stream.truncate_limit = 20
      stream.add_message(role: :assistant, content: 'a' * 100)
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).to include('[truncated]')
    end

    it 'does not truncate short assistant messages' do
      stream.truncate_limit = 200
      stream.add_message(role: :assistant, content: 'short reply')
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).not_to include('[truncated]')
    end

    it 'does not truncate when truncate_limit is nil' do
      stream.truncate_limit = nil
      long_content = 'x' * 500
      stream.add_message(role: :assistant, content: long_content)
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).not_to include('[truncated]')
    end

    it 'preserves original message content after truncated display' do
      stream.truncate_limit = 10
      stream.add_message(role: :assistant, content: 'hello world this is a long message')
      expect(stream.messages.last[:content]).to eq('hello world this is a long message')
    end

    it 'does not apply truncation to user messages' do
      stream.truncate_limit = 10
      stream.add_message(role: :user, content: 'hello world this is a long user message')
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).not_to include('[truncated]')
    end
  end
end
