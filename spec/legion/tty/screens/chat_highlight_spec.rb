# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/highlight command' do
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

  describe '/highlight' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/highlight')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/highlight foo')).to eq(:handled)
    end

    it 'shows usage when no args provided' do
      chat.handle_slash_command('/highlight')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'adds a pattern to @highlights' do
      chat.handle_slash_command('/highlight error')
      highlights = chat.instance_variable_get(:@highlights)
      expect(highlights).to include('error')
    end

    it 'shows confirmation after adding a pattern' do
      chat.handle_slash_command('/highlight warning')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("Highlight added: 'warning'")
    end

    it 'sets highlights on message_stream' do
      chat.handle_slash_command('/highlight mypattern')
      expect(chat.message_stream.highlights).to include('mypattern')
    end

    it 'can accumulate multiple highlights' do
      chat.handle_slash_command('/highlight alpha')
      chat.handle_slash_command('/highlight beta')
      highlights = chat.instance_variable_get(:@highlights)
      expect(highlights).to include('alpha')
      expect(highlights).to include('beta')
    end
  end

  describe '/highlight list' do
    it 'shows "No active highlights." when empty' do
      chat.handle_slash_command('/highlight list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No active highlights.')
    end

    it 'lists all active highlights' do
      chat.instance_variable_set(:@highlights, %w[foo bar])
      chat.handle_slash_command('/highlight list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('foo')
      expect(content).to include('bar')
    end

    it 'shows count of highlights' do
      chat.instance_variable_set(:@highlights, %w[one two three])
      chat.handle_slash_command('/highlight list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('3')
    end
  end

  describe '/highlight clear' do
    it 'clears all highlights' do
      chat.instance_variable_set(:@highlights, %w[foo bar])
      chat.handle_slash_command('/highlight clear')
      highlights = chat.instance_variable_get(:@highlights)
      expect(highlights).to be_empty
    end

    it 'clears highlights on message_stream' do
      chat.instance_variable_set(:@highlights, %w[foo bar])
      chat.handle_slash_command('/highlight clear')
      expect(chat.message_stream.highlights).to be_empty
    end

    it 'shows confirmation after clearing' do
      chat.handle_slash_command('/highlight clear')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Highlights cleared.')
    end
  end
end

RSpec.describe Legion::TTY::Components::MessageStream, 'highlight rendering' do
  subject(:stream) { described_class.new }

  describe '#highlights' do
    it 'initializes to an empty array' do
      expect(stream.highlights).to eq([])
    end

    it 'can be set via attr_accessor' do
      stream.highlights = ['foo']
      expect(stream.highlights).to eq(['foo'])
    end
  end

  describe '#apply_highlights (via render)' do
    it 'wraps matching text with ANSI codes in user messages' do
      stream.highlights = ['hello']
      stream.add_message(role: :user, content: 'say hello world')
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).to include("\e[1;33m")
      expect(joined).to include('hello')
    end

    it 'wraps matching text in assistant messages' do
      stream.highlights = ['important']
      stream.add_message(role: :assistant, content: 'this is important')
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).to include('important')
    end

    it 'does not alter text when highlights are empty' do
      stream.add_message(role: :user, content: 'hello world')
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined).to include('hello world')
      expect(joined).not_to include("\e[1;33m")
    end

    it 'handles multiple highlight patterns' do
      stream.highlights = %w[foo bar]
      stream.add_message(role: :user, content: 'foo and bar together')
      lines = stream.render(width: 80, height: 20)
      joined = lines.join("\n")
      expect(joined.scan("\e[1;33m").size).to be >= 2
    end

    it 'does not raise when highlight pattern is a plain string with no match' do
      stream.highlights = ['zzz']
      stream.add_message(role: :user, content: 'hello world')
      expect { stream.render(width: 80, height: 20) }.not_to raise_error
    end
  end
end
