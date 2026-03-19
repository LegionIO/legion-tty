# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat do
  let(:app) { double('app', config: { name: 'Matt', provider: 'claude' }) }
  let(:output) { StringIO.new }
  let(:mock_input_bar) do
    instance_double(Legion::TTY::Components::InputBar,
                    prompt_string: '> ',
                    show_thinking: nil,
                    clear_thinking: nil,
                    thinking?: false)
  end

  subject(:screen) { described_class.new(app, output: output, input_bar: mock_input_bar) }

  describe '#initialize' do
    it 'stores the app reference' do
      expect(screen.app).to eq(app)
    end

    it 'creates a MessageStream' do
      expect(screen.message_stream).to be_a(Legion::TTY::Components::MessageStream)
    end

    it 'creates a StatusBar' do
      expect(screen.status_bar).to be_a(Legion::TTY::Components::StatusBar)
    end
  end

  describe '#activate' do
    before do
      allow(app).to receive(:config).and_return({ name: 'Matt', provider: 'claude' })
    end

    it 'adds a system welcome message' do
      screen.activate
      expect(screen.message_stream.messages).not_to be_empty
    end

    it 'sets the running state' do
      screen.activate
      expect(screen.running?).to be true
    end

    it 'updates the status bar with provider info' do
      screen.activate
      expect(screen.status_bar).to be_a(Legion::TTY::Components::StatusBar)
    end
  end

  describe '#handle_slash_command' do
    it 'recognizes /help' do
      result = screen.handle_slash_command('/help')
      expect(result).to eq(:handled)
    end

    it 'recognizes /quit' do
      result = screen.handle_slash_command('/quit')
      expect(result).to eq(:quit)
    end

    it 'recognizes /clear' do
      result = screen.handle_slash_command('/clear')
      expect(result).to eq(:handled)
    end

    it 'returns nil for non-commands' do
      result = screen.handle_slash_command('hello world')
      expect(result).to be_nil
    end

    it 'returns nil for empty string' do
      result = screen.handle_slash_command('')
      expect(result).to be_nil
    end

    it 'recognizes /model with argument' do
      result = screen.handle_slash_command('/model claude-opus-4')
      expect(result).to eq(:handled)
    end

    it '/model with no argument shows current model and does not crash' do
      result = screen.handle_slash_command('/model')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Current model:/)
    end

    it '/model with invalid name when with_model raises shows error and does not crash' do
      llm = double('llm_chat')
      allow(llm).to receive(:respond_to?).with(:with_model).and_return(true)
      allow(llm).to receive(:with_model).and_raise(StandardError, 'model not found')
      screen.instance_variable_set(:@llm_chat, llm)
      result = screen.handle_slash_command('/model bad-model-name')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Failed to switch model:/)
    end

    it '/model with no llm_chat shows no active session message' do
      screen.instance_variable_set(:@llm_chat, nil)
      result = screen.handle_slash_command('/model some-model')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No active LLM session.')
    end

    it 'recognizes /session with argument' do
      result = screen.handle_slash_command('/session mysession')
      expect(result).to eq(:handled)
    end

    it 'recognizes /cost' do
      result = screen.handle_slash_command('/cost')
      expect(result).to eq(:handled)
    end

    it 'recognizes /export' do
      result = screen.handle_slash_command('/export')
      expect(result).to eq(:handled)
    end

    it 'recognizes /tools' do
      result = screen.handle_slash_command('/tools')
      expect(result).to eq(:handled)
    end

    it 'recognizes /dashboard' do
      allow(app).to receive(:respond_to?).and_return(false)
      result = screen.handle_slash_command('/dashboard')
      expect(result).to eq(:handled)
    end

    it 'recognizes /hotkeys' do
      allow(app).to receive(:respond_to?).and_return(false)
      result = screen.handle_slash_command('/hotkeys')
      expect(result).to eq(:handled)
    end

    it 'recognizes /save' do
      result = screen.handle_slash_command('/save test-session')
      expect(result).to eq(:handled)
    end

    it 'recognizes /sessions' do
      result = screen.handle_slash_command('/sessions')
      expect(result).to eq(:handled)
    end

    it 'recognizes /load' do
      result = screen.handle_slash_command('/load test-session')
      expect(result).to eq(:handled)
    end

    it 'includes all expected commands' do
      expected = %w[/help /quit /clear /compact /copy /diff /model /session /cost /export /tools /dashboard /hotkeys
                    /save /load /sessions /system /delete /plan /palette /extensions /config /theme /search /grep
                    /stats /personality /undo /history /pin /pins /rename /context /alias /snippet /debug
                    /uptime /time /bookmark /welcome /tips /wc /import /mute /autosave /react /macro /tag /tags
                    /repeat /count /template /fav /favs /log /version
                    /focus /retry /merge /sort
                    /chain /info /scroll /summary
                    /prompt /reset /replace /highlight /multiline
                    /annotate /annotations /filter /truncate
                    /tee /pipe
                    /archive /archives
                    /calc /rand
                    /echo /env
                    /ls /pwd
                    /wrap /number
                    /speak /silent
                    /color /timestamps
                    /top /bottom /head /tail
                    /draft /revise /freq /mark
                    /about /commands /ask /define /status /prefs
                    /stopwatch /ago /goto /inject
                    /transform /concat /prefix /suffix /split /swap
                    /timer /notify]
      expect(described_class::SLASH_COMMANDS).to match_array(expected)
    end

    it 'includes /palette in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/palette')
    end

    it 'includes /extensions in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/extensions')
    end

    it 'includes /config in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/config')
    end

    describe '#handle_extensions_screen' do
      it 'rescues LoadError and adds a system message' do
        allow(screen).to receive(:require_relative).and_raise(LoadError, 'cannot load')
        result = screen.send(:handle_extensions_screen)
        expect(result).to eq(:handled)
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Extensions screen not available.')
      end
    end

    describe '#handle_config_screen' do
      it 'rescues LoadError and adds a system message' do
        allow(screen).to receive(:require_relative).and_raise(LoadError, 'cannot load')
        result = screen.send(:handle_config_screen)
        expect(result).to eq(:handled)
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Config screen not available.')
      end
    end

    describe '/system' do
      it 'calls with_instructions and confirms when llm_chat supports it' do
        llm = double('llm_chat')
        allow(llm).to receive(:respond_to?).with(:with_instructions).and_return(true)
        allow(llm).to receive(:with_instructions)
        screen.instance_variable_set(:@llm_chat, llm)
        result = screen.handle_slash_command('/system hello world')
        expect(result).to eq(:handled)
        expect(llm).to have_received(:with_instructions).with('hello world')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('System prompt updated.')
      end

      it 'shows usage when no argument given' do
        result = screen.handle_slash_command('/system')
        expect(result).to eq(:handled)
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Usage: /system <prompt text>')
      end

      it 'shows error when llm_chat is nil' do
        screen.instance_variable_set(:@llm_chat, nil)
        result = screen.handle_slash_command('/system hello')
        expect(result).to eq(:handled)
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No active LLM session.')
      end
    end

    describe '/delete' do
      it 'calls session_store.delete with the given name' do
        session_store = instance_double(Legion::TTY::SessionStore, delete: nil)
        screen.instance_variable_set(:@session_store, session_store)
        result = screen.handle_slash_command('/delete mysession')
        expect(result).to eq(:handled)
        expect(session_store).to have_received(:delete).with('mysession')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('mysession')
      end

      it 'shows usage when no argument given' do
        result = screen.handle_slash_command('/delete')
        expect(result).to eq(:handled)
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Usage: /delete <session-name>')
      end
    end

    describe '/plan' do
      it 'toggles plan_mode on' do
        result = screen.handle_slash_command('/plan')
        expect(result).to eq(:handled)
        expect(screen.instance_variable_get(:@plan_mode)).to be true
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Plan mode ON')
      end

      it 'toggles plan_mode off when called twice' do
        screen.handle_slash_command('/plan')
        screen.handle_slash_command('/plan')
        expect(screen.instance_variable_get(:@plan_mode)).to be false
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Plan mode OFF')
      end
    end
  end

  describe '#handle_user_message in plan_mode' do
    before { screen.activate }

    it 'bookmarks the message instead of sending to LLM when plan_mode is on' do
      screen.instance_variable_set(:@plan_mode, true)
      allow(screen).to receive(:send_to_llm)
      allow(screen).to receive(:render_screen)
      screen.handle_user_message('do something')
      expect(screen).not_to have_received(:send_to_llm)
      system_msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(system_msgs.last[:content]).to eq('(bookmarked)')
    end
  end

  describe '#handle_user_message' do
    it 'adds user message to stream' do
      screen.activate
      allow(screen).to receive(:send_to_llm)
      screen.handle_user_message('hello')
      user_msgs = screen.message_stream.messages.select { |m| m[:role] == :user }
      expect(user_msgs).not_to be_empty
    end

    it 'adds an assistant message placeholder to stream' do
      screen.activate
      allow(screen).to receive(:send_to_llm)
      screen.handle_user_message('hello')
      assistant_msgs = screen.message_stream.messages.select { |m| m[:role] == :assistant }
      expect(assistant_msgs).not_to be_empty
    end
  end

  describe '#render' do
    before { screen.activate }

    it 'returns an array of lines' do
      result = screen.render(80, 24)
      expect(result).to be_an(Array)
    end

    it 'returns non-empty output' do
      result = screen.render(80, 24)
      expect(result).not_to be_empty
    end
  end

  describe '#handle_input' do
    it 'handles up arrow scroll' do
      result = screen.handle_input(:up)
      expect(result).to eq(:handled)
    end

    it 'handles down arrow scroll' do
      result = screen.handle_input(:down)
      expect(result).to eq(:handled)
    end

    it 'passes unknown keys' do
      result = screen.handle_input(:f5)
      expect(result).to eq(:pass)
    end
  end

  describe 'overlay dismiss on next input' do
    it 'dismisses overlay when input is received while overlay is active' do
      screen_manager = double('screen_manager')
      overlay_app = double('app', config: { name: 'Matt', provider: 'claude' }, llm_chat: nil)
      allow(overlay_app).to receive(:respond_to?).and_return(false)
      allow(overlay_app).to receive(:respond_to?).with(:llm_chat).and_return(true)
      allow(overlay_app).to receive(:respond_to?).with(:screen_manager).and_return(true)
      allow(overlay_app).to receive(:screen_manager).and_return(screen_manager)
      dismissed = false
      allow(screen_manager).to receive(:overlay) { dismissed ? nil : 'Help text' }
      expect(screen_manager).to(receive(:dismiss_overlay).once { dismissed = true })

      overlay_screen = described_class.new(overlay_app, output: output, input_bar: mock_input_bar)
      allow(mock_input_bar).to receive(:read_line).and_return('any input', nil)
      overlay_screen.activate
      overlay_screen.run
    end
  end

  describe '/uptime' do
    it 'returns :handled' do
      result = screen.handle_slash_command('/uptime')
      expect(result).to eq(:handled)
    end

    it 'adds a system message with uptime format' do
      screen.handle_slash_command('/uptime')
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/Session uptime: \d+h \d+m \d+s/)
    end

    it 'reports elapsed time accurately' do
      screen.instance_variable_set(:@session_start, Time.now - 3661)
      screen.handle_slash_command('/uptime')
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to match(/1h 1m 1s/)
    end
  end

  describe '/bookmark' do
    it 'returns :handled when there are no pinned messages' do
      result = screen.handle_slash_command('/bookmark')
      expect(result).to eq(:handled)
    end

    it 'adds a system message when there are no pinned messages' do
      screen.handle_slash_command('/bookmark')
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to eq('No pinned messages to export.')
    end

    it 'exports pinned messages to a file and returns :handled' do
      screen.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'Some pinned content' }])
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
      result = screen.handle_slash_command('/bookmark')
      expect(result).to eq(:handled)
    end

    it 'includes export path in the system message when pinned messages exist' do
      screen.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'Pinned text here' }])
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
      screen.handle_slash_command('/bookmark')
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('bookmarks-')
    end

    it 'handles write errors gracefully' do
      screen.instance_variable_set(:@pinned_messages, [{ role: :assistant, content: 'text' }])
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write).and_raise(Errno::EACCES, 'permission denied')
      result = screen.handle_slash_command('/bookmark')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('Bookmark export failed:')
    end
  end

  describe '/uptime in SLASH_COMMANDS' do
    it 'includes /uptime' do
      expect(described_class::SLASH_COMMANDS).to include('/uptime')
    end

    it 'includes /bookmark' do
      expect(described_class::SLASH_COMMANDS).to include('/bookmark')
    end
  end

  describe '#initialize session_start' do
    it 'sets @session_start on initialization' do
      expect(screen.instance_variable_get(:@session_start)).to be_a(Time)
    end
  end

  describe '#render_overlay' do
    it 'does not crash when overlay is nil' do
      screen_manager = double('screen_manager')
      overlay_app = double('app', config: { name: 'Matt', provider: 'claude' }, llm_chat: nil)
      allow(overlay_app).to receive(:respond_to?).and_return(false)
      allow(overlay_app).to receive(:respond_to?).with(:llm_chat).and_return(true)
      allow(overlay_app).to receive(:respond_to?).with(:screen_manager).and_return(true)
      allow(overlay_app).to receive(:screen_manager).and_return(screen_manager)
      allow(screen_manager).to receive(:overlay).and_return(nil)

      overlay_screen = described_class.new(overlay_app, output: output, input_bar: mock_input_bar)
      expect { overlay_screen.send(:render_screen) }.not_to raise_error
    end
  end
end
