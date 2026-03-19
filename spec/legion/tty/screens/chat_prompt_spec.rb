# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/prompt command' do
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

  describe '/prompt' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/prompt')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/prompt list')).to eq(:handled)
    end

    it 'shows usage when no subcommand given' do
      chat.handle_slash_command('/prompt')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows usage on unknown subcommand' do
      chat.handle_slash_command('/prompt bogus')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/prompt save' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/prompt save')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'reports error when no system prompt is set' do
      llm = double('llm', respond_to?: false, instructions: nil)
      allow(llm).to receive(:respond_to?).with(:instructions).and_return(true)
      allow(llm).to receive(:respond_to?).with(:with_instructions).and_return(true)
      chat.instance_variable_set(:@llm_chat, llm)
      chat.handle_slash_command('/prompt save myname')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No system prompt')
    end

    it 'saves the current system prompt to disk' do
      llm = double('llm')
      allow(llm).to receive(:respond_to?).with(:instructions).and_return(true)
      allow(llm).to receive(:instructions).and_return('You are a helpful assistant.')
      chat.instance_variable_set(:@llm_chat, llm)
      allow(FileUtils).to receive(:mkdir_p)
      expect(File).to receive(:write).with(a_string_including('myprompt.txt'), 'You are a helpful assistant.')
      chat.handle_slash_command('/prompt save myprompt')
    end

    it 'shows confirmation message' do
      llm = double('llm')
      allow(llm).to receive(:respond_to?).with(:instructions).and_return(true)
      allow(llm).to receive(:instructions).and_return('Be concise.')
      chat.instance_variable_set(:@llm_chat, llm)
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
      chat.handle_slash_command('/prompt save concise')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("Prompt 'concise' saved.")
    end
  end

  describe '/prompt load' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/prompt load')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'reports not found for missing prompt' do
      allow(File).to receive(:exist?).and_return(false)
      chat.handle_slash_command('/prompt load ghost')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not found')
    end

    it 'calls with_instructions on llm_chat when prompt exists' do
      llm = double('llm')
      allow(llm).to receive(:respond_to?).with(:with_instructions).and_return(true)
      allow(llm).to receive(:with_instructions).and_return(nil)
      chat.instance_variable_set(:@llm_chat, llm)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('You are a concise assistant.')
      expect(llm).to receive(:with_instructions).with('You are a concise assistant.')
      chat.handle_slash_command('/prompt load concise')
    end

    it 'shows confirmation after loading' do
      llm = double('llm')
      allow(llm).to receive(:respond_to?).with(:with_instructions).and_return(false)
      chat.instance_variable_set(:@llm_chat, llm)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('prompt text')
      chat.handle_slash_command('/prompt load myprompt')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("'myprompt' loaded as system prompt")
    end
  end

  describe '/prompt list' do
    it 'shows "No prompts saved." when directory is empty' do
      allow(Dir).to receive(:glob).and_return([])
      chat.handle_slash_command('/prompt list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No prompts saved.')
    end

    it 'lists prompt names from disk' do
      allow(Dir).to receive(:glob).and_return(['/home/.legionio/prompts/alpha.txt',
                                               '/home/.legionio/prompts/beta.txt'])
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('prompt content')
      chat.handle_slash_command('/prompt list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('alpha')
      expect(content).to include('beta')
    end
  end

  describe '/prompt delete' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/prompt delete')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'reports not found when file does not exist' do
      allow(File).to receive(:exist?).and_return(false)
      chat.handle_slash_command('/prompt delete ghost')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not found')
    end

    it 'deletes the file and shows confirmation' do
      allow(File).to receive(:exist?).and_return(true)
      expect(File).to receive(:delete).with(a_string_including('myprompt.txt'))
      chat.handle_slash_command('/prompt delete myprompt')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include("'myprompt' deleted")
    end
  end
end
