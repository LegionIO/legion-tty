# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/alias command' do
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

  describe '/alias' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/alias')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/alias')).to eq(:handled)
    end

    it 'shows "No aliases defined." when no aliases exist' do
      chat.handle_slash_command('/alias')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No aliases defined.')
    end

    it 'creates an alias with the /alias shortname /command syntax' do
      chat.handle_slash_command('/alias h /help')
      aliases = chat.instance_variable_get(:@aliases)
      expect(aliases['/h']).to eq('/help')
    end

    it 'normalizes the shortname by prepending / if missing' do
      chat.handle_slash_command('/alias q /quit')
      aliases = chat.instance_variable_get(:@aliases)
      expect(aliases.key?('/q')).to be true
    end

    it 'preserves leading / on shortname if already present' do
      chat.handle_slash_command('/alias /q /quit')
      aliases = chat.instance_variable_get(:@aliases)
      expect(aliases['/q']).to eq('/quit')
    end

    it 'shows confirmation message after creating alias' do
      chat.handle_slash_command('/alias h /help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Alias created')
      expect(content).to include('/h')
      expect(content).to include('/help')
    end

    it 'lists all defined aliases when called with no args' do
      chat.instance_variable_set(:@aliases, { '/h' => '/help', '/q' => '/quit' })
      chat.handle_slash_command('/alias')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/h')
      expect(content).to include('/help')
      expect(content).to include('/q')
      expect(content).to include('/quit')
    end

    it 'shows usage when shortname provided but no expansion' do
      chat.handle_slash_command('/alias h')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'allows aliases to include arguments in the expansion' do
      chat.handle_slash_command('/alias cl /compact 10')
      aliases = chat.instance_variable_get(:@aliases)
      expect(aliases['/cl']).to eq('/compact 10')
    end
  end

  describe 'alias expansion in handle_slash_command' do
    before do
      chat.instance_variable_set(:@aliases, { '/h' => '/help' })
    end

    it 'expands alias and dispatches to the real command' do
      result = chat.handle_slash_command('/h')
      expect(result).to eq(:handled)
    end

    it 'dispatched expansion shows the help overlay (e.g., help text)' do
      overlay_text = nil
      allow(app.screen_manager).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/h')
      expect(overlay_text).to include('SESSION')
    end

    it 'returns nil for unknown commands that are not aliases' do
      result = chat.handle_slash_command('/unknown_cmd')
      expect(result).to be_nil
    end

    it 'can expand aliases with arguments' do
      chat.instance_variable_set(:@aliases, { '/cs' => '/search' })
      chat.handle_slash_command('/cs hello')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('hello')
    end
  end

  describe '/help mentions /alias' do
    it 'includes /alias in help text' do
      overlay_text = nil
      allow(app.screen_manager).to receive(:show_overlay) { |text| overlay_text = text }
      chat.handle_slash_command('/help')
      expect(overlay_text).to include('/alias')
    end
  end
end
