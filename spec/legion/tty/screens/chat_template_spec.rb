# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/template command' do
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

  describe 'TEMPLATES constant' do
    it 'is defined on CustomCommands' do
      expect(described_class::CustomCommands::TEMPLATES).to be_a(Hash)
    end

    it 'is frozen' do
      expect(described_class::CustomCommands::TEMPLATES).to be_frozen
    end

    it 'contains at least 8 entries' do
      expect(described_class::CustomCommands::TEMPLATES.size).to be >= 8
    end

    it 'includes explain template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('explain')
    end

    it 'includes review template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('review')
    end

    it 'includes summarize template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('summarize')
    end

    it 'includes refactor template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('refactor')
    end

    it 'includes test template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('test')
    end

    it 'includes debug template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('debug')
    end

    it 'includes translate template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('translate')
    end

    it 'includes compare template' do
      expect(described_class::CustomCommands::TEMPLATES).to have_key('compare')
    end

    it 'has non-empty string values' do
      expect(described_class::CustomCommands::TEMPLATES.values).to all(be_a(String))
      expect(described_class::CustomCommands::TEMPLATES.values).to all(satisfy { |v| !v.empty? })
    end
  end

  describe '/template' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/template')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/template')
      expect(result).to eq(:handled)
    end

    context 'with no argument' do
      it 'lists available templates' do
        chat.handle_slash_command('/template')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('explain')
        expect(content).to include('review')
        expect(content).to include('summarize')
      end

      it 'shows usage hint' do
        chat.handle_slash_command('/template')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('/template <name>')
      end

      it 'shows the template count' do
        chat.handle_slash_command('/template')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to match(/\d+ templates/i).or include('8')
      end
    end

    context 'with a valid template name' do
      it 'shows the template text for explain' do
        chat.handle_slash_command('/template explain')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Explain')
        expect(content).to include('explain')
      end

      it 'shows the template text for review' do
        chat.handle_slash_command('/template review')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Review')
      end

      it 'shows the template text for debug' do
        chat.handle_slash_command('/template debug')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('debug')
      end

      it 'shows the template name in the message' do
        chat.handle_slash_command('/template summarize')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('summarize')
      end
    end

    context 'with an unknown template name' do
      it 'reports template not found' do
        chat.handle_slash_command('/template nonexistent')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('not found')
        expect(content).to include('nonexistent')
      end

      it 'lists available templates in the error message' do
        chat.handle_slash_command('/template nonexistent')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('explain')
      end
    end
  end
end
