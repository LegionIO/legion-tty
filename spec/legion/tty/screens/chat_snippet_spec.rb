# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/snippet command' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil),
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

  describe '/snippet' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/snippet')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/snippet list')).to eq(:handled)
    end

    it 'shows usage when subcommand is missing' do
      chat.handle_slash_command('/snippet')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows usage on unknown subcommand' do
      chat.handle_slash_command('/snippet bogus')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/snippet save' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/snippet save')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'reports error when no assistant message exists' do
      chat.handle_slash_command('/snippet save mysnip')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No assistant message')
    end

    it 'saves the last assistant message content as the snippet' do
      chat.message_stream.add_message(role: :assistant, content: 'the answer is 42')
      allow(File).to receive(:write)
      allow(FileUtils).to receive(:mkdir_p)
      chat.handle_slash_command('/snippet save answer')
      snippets = chat.instance_variable_get(:@snippets)
      expect(snippets['answer']).to eq('the answer is 42')
    end

    it 'shows confirmation message' do
      chat.message_stream.add_message(role: :assistant, content: 'saved content')
      allow(File).to receive(:write)
      allow(FileUtils).to receive(:mkdir_p)
      chat.handle_slash_command('/snippet save myname')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("Snippet 'myname' saved.")
    end

    it 'writes snippet to disk' do
      chat.message_stream.add_message(role: :assistant, content: 'disk content')
      allow(FileUtils).to receive(:mkdir_p)
      expect(File).to receive(:write).with(a_string_including('mysnip.txt'), 'disk content')
      chat.handle_slash_command('/snippet save mysnip')
    end
  end

  describe '/snippet load' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/snippet load')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'reports "not found" for unknown snippet' do
      allow(File).to receive(:exist?).and_return(false)
      chat.handle_slash_command('/snippet load nonexistent')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not found')
    end

    it 'inserts the snippet as a user message from memory' do
      chat.instance_variable_set(:@snippets, { 'greet' => 'Hello, world!' })
      chat.handle_slash_command('/snippet load greet')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs.last[:content]).to eq('Hello, world!')
    end

    it 'shows confirmation after loading' do
      chat.instance_variable_set(:@snippets, { 'greet' => 'Hello!' })
      chat.handle_slash_command('/snippet load greet')
      sys_msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
      expect(sys_msgs.last[:content]).to include("'greet' inserted")
    end

    it 'loads from disk when not in memory' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('disk snippet content')
      chat.handle_slash_command('/snippet load disksnip')
      user_msgs = chat.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs.last[:content]).to eq('disk snippet content')
    end
  end

  describe '/snippet list' do
    it 'shows "No snippets saved." when empty' do
      allow(Dir).to receive(:glob).and_return([])
      chat.handle_slash_command('/snippet list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No snippets saved.')
    end

    it 'lists all in-memory snippets' do
      chat.instance_variable_set(:@snippets, { 'alpha' => 'first content', 'beta' => 'second content' })
      allow(Dir).to receive(:glob).and_return([])
      chat.handle_slash_command('/snippet list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('alpha')
      expect(content).to include('beta')
    end

    it 'shows a preview (truncated) of each snippet' do
      long_text = 'x' * 100
      chat.instance_variable_set(:@snippets, { 'long' => long_text })
      allow(Dir).to receive(:glob).and_return([])
      chat.handle_slash_command('/snippet list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('...')
    end
  end

  describe '/snippet delete' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/snippet delete')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'reports "not found" when snippet does not exist on disk or memory' do
      allow(File).to receive(:exist?).and_return(false)
      chat.handle_slash_command('/snippet delete ghost')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not found')
    end

    it 'removes snippet from memory' do
      chat.instance_variable_set(:@snippets, { 'bye' => 'content' })
      allow(File).to receive(:exist?).and_return(false)
      chat.handle_slash_command('/snippet delete bye')
      snippets = chat.instance_variable_get(:@snippets)
      expect(snippets.key?('bye')).to be false
    end

    it 'deletes file from disk if it exists' do
      allow(File).to receive(:exist?).and_return(true)
      expect(File).to receive(:delete).with(a_string_including('bye.txt'))
      chat.handle_slash_command('/snippet delete bye')
    end

    it 'shows confirmation on deletion' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:delete)
      chat.handle_slash_command('/snippet delete bye')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("'bye' deleted")
    end
  end

  describe '/help mentions /snippet' do
    it 'includes /snippet in help text' do
      chat.handle_slash_command('/help')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/snippet')
    end
  end
end
