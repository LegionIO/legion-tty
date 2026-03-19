# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/number command' do
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
    it 'includes /number' do
      expect(described_class::SLASH_COMMANDS).to include('/number')
    end
  end

  describe '/number on' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/number on')).to eq(:handled)
    end

    it 'sets show_numbers to true on message_stream' do
      chat.handle_slash_command('/number on')
      expect(chat.message_stream.show_numbers).to be true
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/number on')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Message numbering ON.')
    end
  end

  describe '/number off' do
    it 'sets show_numbers to false' do
      chat.message_stream.show_numbers = true
      chat.handle_slash_command('/number off')
      expect(chat.message_stream.show_numbers).to be false
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/number off')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Message numbering OFF.')
    end
  end

  describe '/number (toggle)' do
    it 'toggles show_numbers from false to true' do
      chat.handle_slash_command('/number')
      expect(chat.message_stream.show_numbers).to be true
    end

    it 'toggles show_numbers from true to false' do
      chat.message_stream.show_numbers = true
      chat.handle_slash_command('/number')
      expect(chat.message_stream.show_numbers).to be false
    end

    it 'shows ON message when toggling to true' do
      chat.handle_slash_command('/number')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Message numbering ON.')
    end

    it 'shows OFF message when toggling to false' do
      chat.message_stream.show_numbers = true
      chat.handle_slash_command('/number')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Message numbering OFF.')
    end
  end
end

RSpec.describe Legion::TTY::Components::MessageStream, 'show_numbers rendering' do
  subject(:stream) { described_class.new }

  describe '#show_numbers' do
    it 'initializes to false' do
      expect(stream.show_numbers).to be false
    end

    it 'can be set via attr_accessor' do
      stream.show_numbers = true
      expect(stream.show_numbers).to be true
    end
  end

  describe 'render with show_numbers' do
    before do
      stream.add_message(role: :user, content: 'hello')
      stream.add_message(role: :assistant, content: 'world')
    end

    it 'prepends [1] to first message header line when show_numbers is true' do
      stream.show_numbers = true
      lines = stream.render(width: 80, height: 20)
      numbered = lines.select { |l| l.include?('[1]') }
      expect(numbered).not_to be_empty
    end

    it 'prepends [2] to second message header line when show_numbers is true' do
      stream.show_numbers = true
      lines = stream.render(width: 80, height: 20)
      numbered = lines.select { |l| l.include?('[2]') }
      expect(numbered).not_to be_empty
    end

    it 'does not include [1] when show_numbers is false' do
      stream.show_numbers = false
      lines = stream.render(width: 80, height: 20)
      numbered = lines.grep(/\[1\]/)
      expect(numbered).to be_empty
    end

    it 'returns an Array of strings' do
      stream.show_numbers = true
      lines = stream.render(width: 80, height: 20)
      expect(lines).to all(be_a(String))
    end
  end
end
