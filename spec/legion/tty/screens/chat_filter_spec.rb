# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/filter command' do
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

  describe '/filter in SLASH_COMMANDS' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/filter')
    end
  end

  describe '/filter role' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/filter role user')).to eq(:handled)
    end

    it 'sets role=user filter on message_stream' do
      chat.handle_slash_command('/filter role user')
      expect(chat.message_stream.filter).to eq({ type: :role, value: 'user' })
    end

    it 'sets role=assistant filter on message_stream' do
      chat.handle_slash_command('/filter role assistant')
      expect(chat.message_stream.filter).to eq({ type: :role, value: 'assistant' })
    end

    it 'sets role=system filter on message_stream' do
      chat.handle_slash_command('/filter role system')
      expect(chat.message_stream.filter).to eq({ type: :role, value: 'system' })
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/filter role user')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('role=user')
    end

    it 'shows usage when role value is missing' do
      chat.handle_slash_command('/filter role')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/filter tag' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/filter tag important')).to eq(:handled)
    end

    it 'sets tag filter on message_stream' do
      chat.handle_slash_command('/filter tag important')
      expect(chat.message_stream.filter).to eq({ type: :tag, value: 'important' })
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/filter tag work')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('tag=work')
    end

    it 'shows usage when tag value is missing' do
      chat.handle_slash_command('/filter tag')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/filter pinned' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/filter pinned')).to eq(:handled)
    end

    it 'sets pinned filter on message_stream' do
      chat.handle_slash_command('/filter pinned')
      expect(chat.message_stream.filter).to eq({ type: :pinned })
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/filter pinned')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('pinned')
    end
  end

  describe '/filter clear' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/filter clear')).to eq(:handled)
    end

    it 'clears the filter on message_stream' do
      chat.handle_slash_command('/filter role user')
      chat.handle_slash_command('/filter clear')
      expect(chat.message_stream.filter).to be_nil
    end

    it 'shows confirmation message' do
      chat.handle_slash_command('/filter clear')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('cleared')
    end
  end

  describe '/filter with no args' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/filter')).to eq(:handled)
    end

    it 'shows "No active filter." when no filter is set' do
      chat.handle_slash_command('/filter')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No active filter.')
    end

    it 'shows active role filter status' do
      chat.handle_slash_command('/filter role assistant')
      chat.handle_slash_command('/filter')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('role=assistant')
    end

    it 'shows active pinned filter status' do
      chat.handle_slash_command('/filter pinned')
      chat.handle_slash_command('/filter')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('pinned')
    end

    it 'shows active tag filter status' do
      chat.handle_slash_command('/filter tag work')
      chat.handle_slash_command('/filter')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('tag=work')
    end
  end

  describe '/filter with unknown subcommand' do
    it 'returns :handled' do
      expect(chat.handle_slash_command('/filter unknown')).to eq(:handled)
    end

    it 'shows help/usage message' do
      chat.handle_slash_command('/filter unknown')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end
end
