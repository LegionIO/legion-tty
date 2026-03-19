# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/annotate and /annotations commands' do
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

  describe '/annotate' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/annotate')
    end

    it 'returns :handled' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      expect(chat.handle_slash_command('/annotate this is a note')).to eq(:handled)
    end

    it 'shows usage when no text given' do
      chat.handle_slash_command('/annotate')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'annotates the last assistant message when no index given' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/annotate this is a note')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:annotations]).not_to be_nil
      expect(msg[:annotations].last[:text]).to eq('this is a note')
    end

    it 'stores a timestamp with each annotation' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/annotate timestamped note')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      expect(msg[:annotations].last[:timestamp]).not_to be_nil
    end

    it 'annotates a specific message by index' do
      chat.message_stream.add_message(role: :user, content: 'user question')
      chat.message_stream.add_message(role: :assistant, content: 'assistant answer')
      chat.handle_slash_command('/annotate 0 note on user msg')
      msg = chat.message_stream.messages[0]
      expect(msg[:annotations].last[:text]).to eq('note on user msg')
    end

    it 'shows confirmation after adding annotation' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/annotate my note text')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('my note text')
      expect(content).to include('added')
    end

    it 'shows error when no assistant message exists' do
      chat.handle_slash_command('/annotate some note')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message to annotate.')
    end

    it 'shows error for out-of-range index' do
      chat.handle_slash_command('/annotate 99 some note')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No message to annotate.')
    end

    it 'allows multiple annotations on the same message' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.handle_slash_command('/annotate first note')
      chat.handle_slash_command('/annotate second note')
      msg = chat.message_stream.messages.find { |m| m[:role] == :assistant }
      texts = msg[:annotations].map { |a| a[:text] }
      expect(texts).to include('first note', 'second note')
    end
  end

  describe '/annotations' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/annotations')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/annotations')).to eq(:handled)
    end

    it 'shows "No annotated messages." when none exist' do
      chat.handle_slash_command('/annotations')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No annotated messages.')
    end

    it 'lists all annotations with message index and role' do
      chat.message_stream.add_message(role: :assistant, content: 'response')
      chat.message_stream.messages.last[:annotations] = [{ text: 'my note', timestamp: '2026-03-19T10:00:00+00:00' }]
      chat.handle_slash_command('/annotations')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('my note')
      expect(content).to include('assistant')
    end

    it 'includes message index in annotation listing' do
      chat.message_stream.add_message(role: :user, content: 'question')
      chat.message_stream.add_message(role: :assistant, content: 'answer')
      chat.message_stream.messages.last[:annotations] = [{ text: 'note', timestamp: '2026-03-19T10:00:00+00:00' }]
      chat.handle_slash_command('/annotations')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/\[1\]/)
    end
  end

  describe 'MessageStream annotation rendering' do
    it 'renders annotation lines for assistant messages' do
      stream = Legion::TTY::Components::MessageStream.new
      stream.add_message(role: :assistant, content: 'hello')
      stream.messages.last[:annotations] = [{ text: 'my note', timestamp: '2026-03-19T10:00:00+00:00' }]
      lines = stream.render(width: 80, height: 50)
      note_line = lines.find { |l| l.include?('my note') }
      expect(note_line).not_to be_nil
    end

    it 'renders annotation lines for user messages' do
      stream = Legion::TTY::Components::MessageStream.new
      stream.add_message(role: :user, content: 'user message')
      stream.messages.last[:annotations] = [{ text: 'user annotation', timestamp: '2026-03-19T10:00:00+00:00' }]
      lines = stream.render(width: 80, height: 50)
      note_line = lines.find { |l| l.include?('user annotation') }
      expect(note_line).not_to be_nil
    end

    it 'does not show annotation lines when no annotations present' do
      stream = Legion::TTY::Components::MessageStream.new
      stream.add_message(role: :assistant, content: 'hello')
      lines = stream.render(width: 80, height: 50)
      expect(lines.any? { |l| l.include?('note') }).to be false
    end

    it 'shows timestamp in annotation line' do
      stream = Legion::TTY::Components::MessageStream.new
      stream.add_message(role: :assistant, content: 'hello')
      stream.messages.last[:annotations] = [{ text: 'timed note', timestamp: '2026-03-19T10:30:00+00:00' }]
      lines = stream.render(width: 80, height: 50)
      note_line = lines.find { |l| l.include?('timed note') }
      expect(note_line).to include('10:30')
    end
  end
end
