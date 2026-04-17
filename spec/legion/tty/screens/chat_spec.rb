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

    it 'returns without error' do
      expect { screen.activate }.not_to raise_error
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

    it '/model with a model name stores the preference and confirms' do
      result = screen.handle_slash_command('/model claude-opus-4')
      expect(result).to eq(:handled)
      msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
      expect(msgs.last[:content]).to include('claude-opus-4')
    end

    it '/model preference is applied on next inference call' do
      screen.handle_slash_command('/model custom-model')
      expect(screen.instance_variable_get(:@preferred_model)).to eq('custom-model')
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
      expected = %w[/help /quit /clear /compact /copy /diff /model /session /cost /export /tools /tool /dashboard
                    /hotkeys /save /load /sessions /system /delete /plan /palette /extensions /config /theme /search
                    /grep /stats /personality /undo /history /pin /pins /rename /context /alias /snippet /debug
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
                    /timer /notify /gaia /skills /apollo]
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
    it 'handles page_up scroll' do
      result = screen.handle_input(:page_up)
      expect(result).to eq(:handled)
    end

    it 'handles page_down scroll' do
      result = screen.handle_input(:page_down)
      expect(result).to eq(:handled)
    end

    it 'passes unknown keys' do
      result = screen.handle_input(:f5)
      expect(result).to eq(:pass)
    end
  end

  describe 'needs_input_bar?' do
    it 'returns true for chat screen' do
      expect(screen.needs_input_bar?).to be true
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

  describe '#streaming?' do
    it 'defaults to false' do
      expect(screen.streaming?).to be false
    end
  end

  describe '/tools command' do
    context 'when Legion::Tools::Registry is defined' do
      let(:tool_a) do
        double('tool_a',
               tool_name: 'legion.search',
               description: 'Search for things',
               mcp_tier: 1,
               deferred?: false)
          .tap { |t| allow(t).to receive(:respond_to?).with(:mcp_tier).and_return(true) }
          .tap { |t| allow(t).to receive(:respond_to?).with(:deferred?).and_return(true) }
      end

      let(:tool_b) do
        double('tool_b',
               tool_name: 'legion.infer',
               description: 'Run inference',
               mcp_tier: nil,
               deferred?: true)
          .tap { |t| allow(t).to receive(:respond_to?).with(:mcp_tier).and_return(true) }
          .tap { |t| allow(t).to receive(:respond_to?).with(:deferred?).and_return(true) }
      end

      before do
        registry = Module.new do
          def self.all_tools = []
          def self.tools = []
          def self.deferred_tools = []
        end
        stub_const('Legion::Tools::Registry', registry)
        allow(Legion::Tools::Registry).to receive(:all_tools).and_return([tool_a, tool_b])
        allow(Legion::Tools::Registry).to receive(:tools).and_return([tool_a])
        allow(Legion::Tools::Registry).to receive(:deferred_tools).and_return([tool_b])
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/tools')).to eq(:handled)
      end

      it 'shows tool names in the message' do
        screen.handle_slash_command('/tools')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('legion.search')
        expect(content).to include('legion.infer')
      end

      it 'shows always and deferred counts in header' do
        screen.handle_slash_command('/tools')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to match(/always=1/)
        expect(content).to match(/deferred=1/)
      end

      it 'shows tier tag for tools with mcp_tier' do
        screen.handle_slash_command('/tools')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('[T1]')
      end

      it 'shows deferred tag for deferred tools' do
        screen.handle_slash_command('/tools')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('(deferred)')
      end

      it 'includes tool count in header' do
        screen.handle_slash_command('/tools')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to match(/Legion Tools \(2\)/)
      end
    end

    context 'when Legion::Tools::Registry is not defined' do
      it 'falls back to gem scan (no lex- gems found in test env)' do
        result = screen.handle_slash_command('/tools')
        expect(result).to eq(:handled)
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to satisfy('contain lex info') do |content|
          content.include?('No lex-* extensions found') || content.include?('LEX Extensions')
        end
      end
    end
  end

  describe '/tool command' do
    context 'when Legion::Tools::Registry is defined and tool is found' do
      let(:mock_tool) { double('tool', call: { output: 'result value' }) }

      before do
        registry = Module.new do
          def self.find(_name) = nil
        end
        stub_const('Legion::Tools::Registry', registry)
        allow(Legion::Tools::Registry).to receive(:find).with('legion.search').and_return(mock_tool)
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/tool legion.search')).to eq(:handled)
      end

      it 'calls the tool locally and shows result' do
        screen.handle_slash_command('/tool legion.search')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).not_to be_empty
      end
    end

    context 'when Legion::Tools::Registry is defined but tool not found' do
      before do
        registry = Module.new do
          def self.find(_name) = nil
        end
        stub_const('Legion::Tools::Registry', registry)
        allow(Legion::Tools::Registry).to receive(:find).and_return(nil)
        allow(Legion::TTY::DaemonClient).to receive(:run_tool).and_return({ status: :ok, data: { result: 'ok' } })
      end

      it 'falls back to DaemonClient.run_tool' do
        screen.handle_slash_command('/tool unknown.tool')
        expect(Legion::TTY::DaemonClient).to have_received(:run_tool).with(hash_including(name: 'unknown.tool'))
      end
    end

    context 'when Legion::Tools::Registry is not defined' do
      before do
        allow(Legion::TTY::DaemonClient).to receive(:run_tool).and_return({ status: :ok, data: { result: 'ok' } })
      end

      it 'calls DaemonClient.run_tool' do
        screen.handle_slash_command('/tool some.tool')
        expect(Legion::TTY::DaemonClient).to have_received(:run_tool).with(hash_including(name: 'some.tool'))
      end

      it 'shows unavailable message when daemon not reachable' do
        allow(Legion::TTY::DaemonClient).to receive(:run_tool).and_return({ status: :unavailable })
        screen.handle_slash_command('/tool some.tool')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('unavailable')
      end

      it 'shows error message on error status' do
        allow(Legion::TTY::DaemonClient).to receive(:run_tool)
          .and_return({ status: :error, error: 'HTTP 422' })
        screen.handle_slash_command('/tool some.tool')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Error:')
      end
    end

    context 'when name is blank' do
      it 'shows usage message' do
        screen.handle_slash_command('/tool')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Usage:')
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/tool')).to eq(:handled)
      end
    end
  end

  describe '#maybe_route_to_tool' do
    let(:message) { 'search for something' }

    context 'when Legion::Tools::TriggerIndex is not defined' do
      it 'returns nil' do
        hide_const('Legion::Tools::TriggerIndex')
        result = screen.send(:maybe_route_to_tool, message)
        expect(result).to be_nil
      end
    end

    context 'when Legion::Tools::TriggerIndex is defined but empty' do
      before do
        trigger_index = Module.new do
          def self.empty? = true
          def self.match(_words) = [Set.new, nil]
        end
        stub_const('Legion::Tools::TriggerIndex', trigger_index)
      end

      it 'returns nil' do
        result = screen.send(:maybe_route_to_tool, message)
        expect(result).to be_nil
      end
    end

    context 'when TriggerIndex has words but no match for the message' do
      before do
        trigger_index = Module.new do
          def self.empty? = false
          def self.match(_words) = [Set.new, nil]
        end
        stub_const('Legion::Tools::TriggerIndex', trigger_index)
      end

      it 'returns nil when matched set is empty' do
        result = screen.send(:maybe_route_to_tool, message)
        expect(result).to be_nil
      end
    end

    context 'when a match is found' do
      let(:tool_result) { { output: 'tool ran successfully' } }

      before do
        trigger_index = Module.new do
          def self.empty? = false
          def self.match(_words) = [Set.new(['legion.search']), nil]
        end
        stub_const('Legion::Tools::TriggerIndex', trigger_index)

        tools_do = Module.new do
          def self.call(**) = nil
        end
        stub_const('Legion::Tools::Do', tools_do)
        allow(Legion::Tools::Do).to receive(:call).with(intent: message).and_return(tool_result)
      end

      it 'calls Legion::Tools::Do.call with intent: message' do
        screen.send(:maybe_route_to_tool, message)
        expect(Legion::Tools::Do).to have_received(:call).with(intent: message)
      end

      it 'returns the result from Legion::Tools::Do.call' do
        result = screen.send(:maybe_route_to_tool, message)
        expect(result).to eq(tool_result)
      end
    end

    context 'when StandardError is raised' do
      before do
        trigger_index = Module.new do
          def self.empty? = false
          def self.match(_words) = raise(StandardError, 'unexpected failure')
        end
        stub_const('Legion::Tools::TriggerIndex', trigger_index)
      end

      it 'returns nil on StandardError (rescue path)' do
        result = screen.send(:maybe_route_to_tool, message)
        expect(result).to be_nil
      end
    end
  end

  describe '#build_tool_schemas' do
    context 'when Legion::Tools::Registry is defined' do
      let(:mock_tool) do
        double('tool',
               tool_name: 'legion.search',
               description: 'Search docs',
               input_schema: { type: 'object', properties: { query: { type: 'string' } } })
      end

      before do
        registry = Module.new do
          def self.tools = []
        end
        stub_const('Legion::Tools::Registry', registry)
        allow(Legion::Tools::Registry).to receive(:tools).and_return([mock_tool])
      end

      it 'returns an array of hashes' do
        schemas = screen.send(:build_tool_schemas)
        expect(schemas).to be_an(Array)
        expect(schemas.size).to eq(1)
      end

      it 'includes :name, :description, :input_schema keys' do
        schema = screen.send(:build_tool_schemas).first
        expect(schema).to include(:name, :description, :input_schema)
      end

      it 'uses the tool_name for :name' do
        schema = screen.send(:build_tool_schemas).first
        expect(schema[:name]).to eq('legion.search')
      end

      it 'falls back to empty object schema when input_schema is nil' do
        allow(mock_tool).to receive(:input_schema).and_return(nil)
        schema = screen.send(:build_tool_schemas).first
        expect(schema[:input_schema]).to eq({ type: 'object', properties: {} })
      end
    end

    context 'when Legion::Tools::Registry is not defined' do
      it 'returns an empty array' do
        schemas = screen.send(:build_tool_schemas)
        expect(schemas).to eq([])
      end
    end
  end

  describe '/skills command' do
    context 'when Registry is defined with skills' do
      let(:skill_a) do
        double('skill_a',
               namespace: 'core',
               skill_name: 'summarize',
               trigger: :on_request,
               trigger_words: %w[summarize recap],
               description: 'Summarizes the conversation')
      end

      let(:skill_b) do
        double('skill_b',
               namespace: 'meta',
               skill_name: 'reflect',
               trigger: :auto_inject,
               trigger_words: [],
               description: 'Reflects on the context')
      end

      before do
        registry = Module.new do
          def self.all = []
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
        allow(Legion::LLM::Skills::Registry).to receive(:all).and_return([skill_a, skill_b])
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills')).to eq(:handled)
      end

      it 'shows header with skill count' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to match(/LLM Skills \(2\)/)
      end

      it 'shows namespace:name for each skill' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('core:summarize')
        expect(content).to include('meta:reflect')
      end

      it 'shows trigger for each skill' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('on_request')
        expect(content).to include('auto_inject')
      end

      it 'shows trigger_words when non-empty' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('[summarize, recap]')
      end

      it 'omits trigger_words bracket when empty' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).not_to match(/meta:reflect.*\[/)
      end

      it 'includes truncated description' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Summarizes the conversation')
      end
    end

    context 'when Registry is defined but empty' do
      before do
        registry = Module.new do
          def self.all = []
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
        allow(Legion::LLM::Skills::Registry).to receive(:all).and_return([])
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills')).to eq(:handled)
      end

      it 'shows no-skills message' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No skills registered.')
      end
    end

    context 'when Registry is not defined' do
      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills')).to eq(:handled)
      end

      it 'shows not-available message' do
        screen.handle_slash_command('/skills')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Legion::LLM::Skills not available.')
      end
    end
  end

  describe '/skills load' do
    context 'when DiskLoader is defined and file exists' do
      let(:path) { '/tmp/test_skill.md' }

      before do
        disk_loader = Module.new do
          def self.load_md_skill(_path) = nil
        end
        stub_const('Legion::LLM::Skills::DiskLoader', disk_loader)
        allow(Legion::LLM::Skills::DiskLoader).to receive(:load_md_skill)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(path).and_return(true)
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command("/skills load #{path}")).to eq(:handled)
      end

      it 'calls DiskLoader.load_md_skill with the expanded path' do
        screen.handle_slash_command("/skills load #{path}")
        expect(Legion::LLM::Skills::DiskLoader).to have_received(:load_md_skill).with(path)
      end

      it 'shows success message' do
        screen.handle_slash_command("/skills load #{path}")
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Skill loaded from:')
        expect(msgs.last[:content]).to include(path)
      end

      it 'shows error message when load_md_skill raises' do
        allow(Legion::LLM::Skills::DiskLoader).to receive(:load_md_skill).and_raise(StandardError, 'parse error')
        screen.handle_slash_command("/skills load #{path}")
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Skill load failed: parse error')
      end
    end

    context 'when file does not exist' do
      let(:missing_path) { '/tmp/nonexistent_skill_xyz.md' }

      before do
        disk_loader = Module.new do
          def self.load_md_skill(_path) = nil
        end
        stub_const('Legion::LLM::Skills::DiskLoader', disk_loader)
        allow(Legion::LLM::Skills::DiskLoader).to receive(:load_md_skill)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(missing_path).and_return(false)
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command("/skills load #{missing_path}")).to eq(:handled)
      end

      it 'shows file-not-found error' do
        screen.handle_slash_command("/skills load #{missing_path}")
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('File not found:')
      end

      it 'does not call load_md_skill' do
        screen.handle_slash_command("/skills load #{missing_path}")
        expect(Legion::LLM::Skills::DiskLoader).not_to have_received(:load_md_skill)
      end
    end

    context 'when DiskLoader is not defined' do
      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills load /some/path.md')).to eq(:handled)
      end

      it 'shows not-available message' do
        screen.handle_slash_command('/skills load /some/path.md')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Legion::LLM::Skills not available.')
      end
    end
  end

  describe '/skills run' do
    context 'when skill is found' do
      let(:skill_result) { double('result', inject: 'Injected context text') }
      let(:skill_instance) { double('skill_instance', run: skill_result) }
      let(:skill_klass) { double('skill_klass', new: skill_instance) }

      before do
        registry = Module.new do
          def self.find(_key) = nil
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
        allow(Legion::LLM::Skills::Registry).to receive(:find).with('core:summarize').and_return(skill_klass)
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills run core:summarize')).to eq(:handled)
      end

      it 'calls klass.new.run with conversation context' do
        screen.handle_slash_command('/skills run core:summarize')
        expect(skill_instance).to have_received(:run).with(hash_including(context: hash_including(:conversation_id)))
      end

      it 'shows the inject content' do
        screen.handle_slash_command('/skills run core:summarize')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Injected context text')
      end

      it 'shows fallback message when inject is empty' do
        allow(skill_result).to receive(:inject).and_return('')
        screen.handle_slash_command('/skills run core:summarize')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Skill ran (no injection).')
      end

      it 'shows error message when run raises' do
        allow(skill_instance).to receive(:run).and_raise(StandardError, 'runtime error')
        screen.handle_slash_command('/skills run core:summarize')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Skill run failed: runtime error')
      end
    end

    context 'when skill is not found' do
      before do
        registry = Module.new do
          def self.find(_key) = nil
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
        allow(Legion::LLM::Skills::Registry).to receive(:find).and_return(nil)
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills run unknown:skill')).to eq(:handled)
      end

      it 'shows skill-not-found error' do
        screen.handle_slash_command('/skills run unknown:skill')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Skill not found: unknown:skill')
      end
    end

    context 'when key is blank' do
      before do
        registry = Module.new do
          def self.find(_key) = nil
        end
        stub_const('Legion::LLM::Skills::Registry', registry)
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills run')).to eq(:handled)
      end

      it 'shows usage message' do
        screen.handle_slash_command('/skills run')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Usage: /skills run <namespace>:<name>')
      end
    end

    context 'when Registry is not defined' do
      it 'returns :handled' do
        expect(screen.handle_slash_command('/skills run core:summarize')).to eq(:handled)
      end

      it 'shows not-available message' do
        screen.handle_slash_command('/skills run core:summarize')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Legion::LLM::Skills not available.')
      end
    end
  end

  describe '/apollo command' do
    def make_apollo_mod(started: true, query_result: nil, ingest_result: nil, graph_result: nil)
      started_val = started
      qr = query_result
      ir = ingest_result
      gr = graph_result
      Module.new do
        define_singleton_method(:started?) { started_val }
        define_singleton_method(:transport_available?) { true }
        define_singleton_method(:data_available?)   { true }
        define_singleton_method(:query)             { |**_| qr } if qr
        define_singleton_method(:ingest)            { |**_| ir } if ir
        define_singleton_method(:graph_query)       { |**_| gr } if gr
      end
    end

    context 'when /apollo (no sub-command) with Legion::Apollo defined' do
      before { stub_const('Legion::Apollo', make_apollo_mod) }

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo')).to eq(:handled)
      end

      it 'shows started/transport/data status' do
        screen.handle_slash_command('/apollo')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to match(/Apollo: started=yes/)
        expect(msgs.last[:content]).to match(/transport=yes/)
        expect(msgs.last[:content]).to match(/data=yes/)
      end
    end

    context 'when /apollo status when Apollo not defined' do
      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo')).to eq(:handled)
      end

      it 'shows not-available message' do
        screen.handle_slash_command('/apollo')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Legion::Apollo not available.')
      end
    end

    context '/apollo query <text> success' do
      before do
        stub_const('Legion::Apollo', make_apollo_mod(
                                       query_result: {
                                         success: true,
                                         entries: [
                                           { confidence: 0.95, content: 'Ruby is a dynamic language' },
                                           { confidence: 0.88, content: 'Rails is built on Ruby' }
                                         ]
                                       }
                                     ))
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo query ruby')).to eq(:handled)
      end

      it 'shows ranked entries with confidence' do
        screen.handle_slash_command('/apollo query ruby')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Apollo results (2)')
        expect(content).to include('[1]')
        expect(content).to include('0.95')
        expect(content).to include('Ruby is a dynamic language')
      end
    end

    context '/apollo query <text> with empty results' do
      before do
        stub_const('Legion::Apollo', make_apollo_mod(query_result: { success: true, entries: [] }))
      end

      it 'shows No results found message' do
        screen.handle_slash_command('/apollo query nothing')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No results found.')
      end
    end

    context '/apollo query <text> failure' do
      before do
        stub_const('Legion::Apollo', make_apollo_mod(
                                       query_result: { success: false, error: 'database offline' }
                                     ))
      end

      it 'shows error message' do
        screen.handle_slash_command('/apollo query ruby')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Apollo query failed: database offline')
      end
    end

    context '/apollo query with blank text' do
      before { stub_const('Legion::Apollo', make_apollo_mod) }

      it 'shows usage message' do
        screen.handle_slash_command('/apollo query')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Usage: /apollo query <text>')
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo query')).to eq(:handled)
      end
    end

    context '/apollo query when Apollo not started' do
      before { stub_const('Legion::Apollo', make_apollo_mod(started: false)) }

      it 'shows Apollo not started message' do
        screen.handle_slash_command('/apollo query hello')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Apollo not started.')
      end
    end

    context '/apollo ingest <text> success' do
      before do
        stub_const('Legion::Apollo', make_apollo_mod(
                                       ingest_result: { success: true, mode: 'local' }
                                     ))
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo ingest some text')).to eq(:handled)
      end

      it 'shows Ingested with mode' do
        screen.handle_slash_command('/apollo ingest some text')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Ingested (local).')
      end
    end

    context '/apollo ingest with blank text' do
      before { stub_const('Legion::Apollo', make_apollo_mod) }

      it 'shows usage message' do
        screen.handle_slash_command('/apollo ingest')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Usage: /apollo ingest <text>')
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo ingest')).to eq(:handled)
      end
    end

    context '/apollo graph <id> success' do
      before do
        stub_const('Legion::Apollo', make_apollo_mod(
                                       graph_result: {
                                         success: true,
                                         nodes: [
                                           { id: 1, label: 'Ruby', content: 'Ruby language' },
                                           { id: 2, label: nil, content: 'Rails framework built on Ruby' }
                                         ]
                                       }
                                     ))
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo graph 42')).to eq(:handled)
      end

      it 'shows graph node count and nodes' do
        screen.handle_slash_command('/apollo graph 42')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Graph (2 nodes)')
        expect(content).to include('[1]')
        expect(content).to include('Ruby')
      end
    end

    context '/apollo graph with invalid entity_id' do
      before { stub_const('Legion::Apollo', make_apollo_mod) }

      it 'shows invalid entity_id message' do
        screen.handle_slash_command('/apollo graph notanumber')
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Invalid entity_id:')
      end

      it 'returns :handled' do
        expect(screen.handle_slash_command('/apollo graph notanumber')).to eq(:handled)
      end
    end

    context '/apollo autoingest toggles @apollo_autoingest' do
      it 'starts as false' do
        expect(screen.instance_variable_get(:@apollo_autoingest)).to be false
      end

      it 'toggles to ON on first call' do
        screen.handle_slash_command('/apollo autoingest')
        expect(screen.instance_variable_get(:@apollo_autoingest)).to be true
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Apollo autoingest: ON')
      end

      it 'toggles back to OFF on second call' do
        screen.handle_slash_command('/apollo autoingest')
        screen.handle_slash_command('/apollo autoingest')
        expect(screen.instance_variable_get(:@apollo_autoingest)).to be false
        msgs = screen.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('Apollo autoingest: OFF')
      end
    end

    it 'includes /apollo in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/apollo')
    end
  end
end
