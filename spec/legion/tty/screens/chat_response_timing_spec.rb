# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'new commands: timing, /wc, /import, /mute' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude', name: 'Jane' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil,
                                                 dismiss_overlay: nil, show_overlay: nil),
                    hotkeys: double('hk', list: []),
                    respond_to?: true)
  end

  before do
    allow(reader).to receive(:on)
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(false)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  # ---------------------------------------------------------------------------
  # Feature 1: Response timing
  # ---------------------------------------------------------------------------
  describe 'response timing via send_via_direct' do
    let(:llm) { double('llm_chat') }

    before do
      chat.instance_variable_set(:@llm_chat, llm)
      allow(chat).to receive(:render_screen)
    end

    it 'sets @last_response_time after a successful call' do
      allow(llm).to receive(:ask).and_yield(double(content: 'hello'))
      chat.message_stream.add_message(role: :assistant, content: '')
      chat.send(:send_via_direct, 'ping')
      expect(chat.instance_variable_get(:@last_response_time)).to be_a(Float)
    end

    it '@last_response_time is non-negative' do
      allow(llm).to receive(:ask).and_yield(double(content: 'hello'))
      chat.message_stream.add_message(role: :assistant, content: '')
      chat.send(:send_via_direct, 'ping')
      expect(chat.instance_variable_get(:@last_response_time)).to be >= 0
    end

    it 'stores response_time on the last message' do
      allow(llm).to receive(:ask).and_yield(double(content: 'world'))
      chat.message_stream.add_message(role: :assistant, content: '')
      chat.send(:send_via_direct, 'ping')
      expect(chat.message_stream.messages.last[:response_time]).to be_a(Float)
    end

    it 'notifies the status bar with the response time' do
      allow(llm).to receive(:ask).and_yield(double(content: 'ok'))
      chat.message_stream.add_message(role: :assistant, content: '')
      expect(chat.status_bar).to receive(:notify).with(
        hash_including(message: a_string_matching(/Response:.*s/), level: :info, ttl: 4)
      )
      chat.send(:send_via_direct, 'ping')
    end

    it 'initializes @muted_system to false' do
      expect(chat.instance_variable_get(:@muted_system)).to be false
    end
  end

  describe '/stats with response_time data' do
    it 'includes average response time when messages have response_time' do
      chat.message_stream.add_message(role: :assistant, content: 'reply one')
      chat.message_stream.messages.last[:response_time] = 1.5
      chat.message_stream.add_message(role: :assistant, content: 'reply two')
      chat.message_stream.messages.last[:response_time] = 2.5
      chat.handle_slash_command('/stats')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Avg response time:')
    end

    it 'shows the correct average response time' do
      chat.message_stream.add_message(role: :assistant, content: 'a')
      chat.message_stream.messages.last[:response_time] = 1.0
      chat.message_stream.add_message(role: :assistant, content: 'b')
      chat.message_stream.messages.last[:response_time] = 3.0
      chat.handle_slash_command('/stats')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('2.0s')
    end

    it 'omits average response time when no messages have response_time' do
      chat.message_stream.add_message(role: :user, content: 'hello')
      chat.handle_slash_command('/stats')
      content = chat.message_stream.messages.last[:content]
      expect(content).not_to include('Avg response time')
    end

    it 'shows how many responses contributed to the average' do
      chat.message_stream.add_message(role: :assistant, content: 'x')
      chat.message_stream.messages.last[:response_time] = 0.5
      chat.handle_slash_command('/stats')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('1 responses')
    end
  end

  # ---------------------------------------------------------------------------
  # Feature 2: /wc
  # ---------------------------------------------------------------------------
  describe '/wc' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/wc')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/wc')).to eq(:handled)
    end

    it 'adds a system message with word count header' do
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Word count:')
    end

    it 'shows Total line' do
      chat.message_stream.add_message(role: :user, content: 'one two three')
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Total:')
    end

    it 'shows User line' do
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('User:')
    end

    it 'shows Assistant line' do
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Assistant:')
    end

    it 'shows System line' do
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('System:')
    end

    it 'shows Avg words/message line' do
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Avg words/message:')
    end

    it 'counts user words correctly' do
      chat.message_stream.add_message(role: :user, content: 'alpha beta gamma')
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/User:\s*3/)
    end

    it 'counts assistant words correctly' do
      chat.message_stream.add_message(role: :assistant, content: 'one two')
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/Assistant:\s*2/)
    end

    it 'counts across multiple messages of the same role' do
      chat.message_stream.add_message(role: :user, content: 'hello world')
      chat.message_stream.add_message(role: :user, content: 'foo bar baz')
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to match(/User:\s*5/)
    end

    it 'formats total with comma separator for large numbers' do
      # 1100 words total
      chat.message_stream.add_message(role: :user, content: ('word ' * 1100).strip)
      chat.handle_slash_command('/wc')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('1,100')
    end

    it 'works on an empty conversation' do
      expect { chat.handle_slash_command('/wc') }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # Feature 3: /import
  # ---------------------------------------------------------------------------
  describe '/import' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/import')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/import')
      expect(result).to eq(:handled)
    end

    it 'shows usage when no path is given' do
      chat.handle_slash_command('/import')
      content = chat.message_stream.messages.last[:content]
      expect(content).to eq('Usage: /import <path>')
    end

    it 'shows file not found when path does not exist' do
      chat.handle_slash_command('/import /nonexistent/path/chat.json')
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('File not found:')
    end

    it 'shows error when file is not valid JSON' do
      path = '/tmp/bad_chat_test.json'
      File.write(path, 'this is not json {{{')
      chat.handle_slash_command("/import #{path}")
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Invalid JSON:')
    ensure
      FileUtils.rm_f(path)
    end

    it 'shows error when JSON is valid but has no messages key' do
      path = '/tmp/no_messages_test.json'
      File.write(path, '{"foo": "bar"}')
      chat.handle_slash_command("/import #{path}")
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('missing messages array')
    ensure
      FileUtils.rm_f(path)
    end

    it 'replaces current messages with imported messages' do
      path = '/tmp/valid_import_test.json'
      data = { messages: [{ role: 'user', content: 'imported message' }] }
      File.write(path, JSON.generate(data))
      chat.handle_slash_command("/import #{path}")
      roles = chat.message_stream.messages.map { |m| m[:role] }
      expect(roles).to include(:user)
      expect(chat.message_stream.messages.any? { |m| m[:content] == 'imported message' }).to be true
    ensure
      FileUtils.rm_f(path)
    end

    it 'adds a system confirmation message after import' do
      path = '/tmp/confirm_import_test.json'
      data = { messages: [{ role: 'user', content: 'hi' }, { role: 'assistant', content: 'hello' }] }
      File.write(path, JSON.generate(data))
      chat.handle_slash_command("/import #{path}")
      # last message is the system confirmation appended after replace
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('Imported')
      expect(content).to include('messages')
    ensure
      FileUtils.rm_f(path)
    end

    it 'notifies the status bar on successful import' do
      path = '/tmp/notify_import_test.json'
      data = { messages: [{ role: 'user', content: 'test' }] }
      File.write(path, JSON.generate(data))
      expect(chat.status_bar).to receive(:notify).with(
        hash_including(level: :success)
      )
      chat.handle_slash_command("/import #{path}")
    ensure
      FileUtils.rm_f(path)
    end

    it 'converts role strings to symbols during import' do
      path = '/tmp/symbol_import_test.json'
      data = { messages: [{ role: 'assistant', content: 'hey' }] }
      File.write(path, JSON.generate(data))
      chat.handle_slash_command("/import #{path}")
      imported = chat.message_stream.messages.find { |m| m[:content] == 'hey' }
      expect(imported[:role]).to eq(:assistant)
    ensure
      FileUtils.rm_f(path)
    end

    it 'expands ~ in path' do
      # Just verifies it doesn't raise on a non-existent home path
      result = chat.handle_slash_command('/import ~/nonexistent_legion_import_test.json')
      expect(result).to eq(:handled)
      content = chat.message_stream.messages.last[:content]
      expect(content).to include('File not found:')
    end
  end

  # ---------------------------------------------------------------------------
  # Feature 4: /mute
  # ---------------------------------------------------------------------------
  describe '/mute' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/mute')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/mute')).to eq(:handled)
    end

    it 'toggles @muted_system to true on first call' do
      chat.handle_slash_command('/mute')
      expect(chat.instance_variable_get(:@muted_system)).to be true
    end

    it 'toggles @muted_system back to false on second call' do
      chat.handle_slash_command('/mute')
      chat.handle_slash_command('/mute')
      expect(chat.instance_variable_get(:@muted_system)).to be false
    end

    it 'sets mute_system on the message stream when toggled on' do
      chat.handle_slash_command('/mute')
      expect(chat.message_stream.mute_system).to be true
    end

    it 'clears mute_system on the message stream when toggled off' do
      chat.handle_slash_command('/mute')
      chat.handle_slash_command('/mute')
      expect(chat.message_stream.mute_system).to be false
    end

    it 'notifies "System messages hidden" when muting' do
      expect(chat.status_bar).to receive(:notify).with(
        hash_including(message: 'System messages hidden', level: :info)
      )
      chat.handle_slash_command('/mute')
    end

    it 'notifies "System messages visible" when unmuting' do
      chat.handle_slash_command('/mute')
      expect(chat.status_bar).to receive(:notify).with(
        hash_including(message: 'System messages visible', level: :info)
      )
      chat.handle_slash_command('/mute')
    end
  end

  describe 'MessageStream#mute_system' do
    let(:stream) { Legion::TTY::Components::MessageStream.new }

    it 'defaults to false' do
      expect(stream.mute_system).to be false
    end

    it 'can be set to true' do
      stream.mute_system = true
      expect(stream.mute_system).to be true
    end

    it 'hides system messages when mute_system is true' do
      stream.add_message(role: :system, content: 'hidden')
      stream.add_message(role: :user, content: 'visible')
      stream.mute_system = true
      lines = stream.render(width: 80, height: 100)
      joined = lines.join("\n")
      expect(joined).not_to include('hidden')
      expect(joined).to include('visible')
    end

    it 'shows system messages when mute_system is false' do
      stream.add_message(role: :system, content: 'shown system msg')
      stream.mute_system = false
      lines = stream.render(width: 80, height: 100)
      joined = lines.join("\n")
      expect(joined).to include('shown system msg')
    end

    it 'does not affect user or assistant messages when muted' do
      stream.add_message(role: :user, content: 'user text')
      stream.add_message(role: :assistant, content: 'assistant text')
      stream.add_message(role: :system, content: 'system text')
      stream.mute_system = true
      lines = stream.render(width: 80, height: 100)
      joined = lines.join("\n")
      expect(joined).to include('user text')
      expect(joined).to include('assistant text')
      expect(joined).not_to include('system text')
    end
  end
end
