# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/macro command' do
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

  describe '/macro' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/macro')
    end

    it 'returns :handled for subcommands' do
      expect(chat.handle_slash_command('/macro list')).to eq(:handled)
    end

    it 'shows usage for unknown subcommand' do
      chat.handle_slash_command('/macro bogus')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end
  end

  describe '/macro record' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/macro record')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'sets @recording_macro to the given name' do
      chat.handle_slash_command('/macro record mymacro')
      expect(chat.instance_variable_get(:@recording_macro)).to eq('mymacro')
    end

    it 'clears @macro_buffer when starting a new recording' do
      chat.instance_variable_set(:@macro_buffer, ['/clear'])
      chat.handle_slash_command('/macro record fresh')
      expect(chat.instance_variable_get(:@macro_buffer)).to be_empty
    end

    it 'shows recording started message' do
      chat.handle_slash_command('/macro record mymacro')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('mymacro')
      expect(content).to include('Recording')
    end
  end

  describe '/macro stop' do
    it 'shows message when no recording is in progress' do
      chat.handle_slash_command('/macro stop')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('No macro recording')
    end

    it 'saves the recorded commands into @macros' do
      chat.instance_variable_set(:@recording_macro, 'test')
      chat.instance_variable_set(:@macro_buffer, ['/clear', '/stats'])
      chat.handle_slash_command('/macro stop')
      macros = chat.instance_variable_get(:@macros)
      expect(macros['test']).to eq(['/clear', '/stats'])
    end

    it 'clears @recording_macro after stopping' do
      chat.instance_variable_set(:@recording_macro, 'test')
      chat.instance_variable_set(:@macro_buffer, [])
      chat.handle_slash_command('/macro stop')
      expect(chat.instance_variable_get(:@recording_macro)).to be_nil
    end

    it 'clears @macro_buffer after stopping' do
      chat.instance_variable_set(:@recording_macro, 'test')
      chat.instance_variable_set(:@macro_buffer, ['/clear'])
      chat.handle_slash_command('/macro stop')
      expect(chat.instance_variable_get(:@macro_buffer)).to be_empty
    end

    it 'shows confirmation with macro name and count' do
      chat.instance_variable_set(:@recording_macro, 'mytest')
      chat.instance_variable_set(:@macro_buffer, ['/stats', '/clear'])
      chat.handle_slash_command('/macro stop')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('mytest')
      expect(content).to include('2')
    end
  end

  describe '/macro play' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/macro play')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows error when macro does not exist' do
      chat.handle_slash_command('/macro play nonexistent')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not found')
    end

    it 'replays each command in the macro' do
      chat.instance_variable_set(:@macros, { 'seq' => ['/stats', '/uptime'] })
      chat.handle_slash_command('/macro play seq')
      contents = chat.message_stream.messages.map { |m| m[:content] }
      expect(contents.any? { |c| c.include?('Messages:') }).to be true
      expect(contents.any? { |c| c.include?('uptime') }).to be true
    end

    it 'shows playing announcement message' do
      chat.instance_variable_set(:@macros, { 'seq' => ['/stats'] })
      chat.handle_slash_command('/macro play seq')
      contents = chat.message_stream.messages.map { |m| m[:content] }
      expect(contents.any? { |c| c.include?('Playing') && c.include?('seq') }).to be true
    end
  end

  describe '/macro list' do
    it 'shows "No macros defined." when no macros exist' do
      chat.handle_slash_command('/macro list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('No macros defined.')
    end

    it 'lists macros with name and command count' do
      chat.instance_variable_set(:@macros, { 'mymacro' => ['/stats', '/clear', '/history'] })
      chat.handle_slash_command('/macro list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('mymacro')
      expect(content).to include('3')
    end

    it 'shows a preview of commands in each macro' do
      chat.instance_variable_set(:@macros, { 'preview' => ['/stats', '/clear'] })
      chat.handle_slash_command('/macro list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('/stats')
    end

    it 'indicates when recording is in progress' do
      chat.instance_variable_set(:@macros, { 'existing' => ['/stats'] })
      chat.instance_variable_set(:@recording_macro, 'inprogress')
      chat.handle_slash_command('/macro list')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('recording')
    end
  end

  describe '/macro delete' do
    it 'shows usage when name is missing' do
      chat.handle_slash_command('/macro delete')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Usage:')
    end

    it 'shows error when macro does not exist' do
      chat.handle_slash_command('/macro delete ghost')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('not found')
    end

    it 'removes the macro from @macros' do
      chat.instance_variable_set(:@macros, { 'removeme' => ['/stats'] })
      chat.handle_slash_command('/macro delete removeme')
      expect(chat.instance_variable_get(:@macros)).not_to have_key('removeme')
    end

    it 'shows confirmation on deletion' do
      chat.instance_variable_set(:@macros, { 'removeme' => ['/stats'] })
      chat.handle_slash_command('/macro delete removeme')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('removeme')
      expect(content).to include('deleted')
    end
  end

  describe 'macro recording integration' do
    it 'records slash commands dispatched while recording' do
      chat.handle_slash_command('/macro record myseq')
      chat.handle_slash_command('/stats')
      chat.handle_slash_command('/macro stop')
      macros = chat.instance_variable_get(:@macros)
      expect(macros['myseq']).to include('/stats')
    end

    it 'does not record /macro commands into the buffer' do
      chat.handle_slash_command('/macro record myseq')
      chat.handle_slash_command('/stats')
      chat.handle_slash_command('/macro stop')
      macros = chat.instance_variable_get(:@macros)
      expect(macros['myseq']).not_to include('/macro stop')
      expect(macros['myseq']).not_to include('/macro record myseq')
    end
  end

  describe '@macros initialized' do
    it 'starts as empty hash' do
      expect(chat.instance_variable_get(:@macros)).to eq({})
    end
  end
end
