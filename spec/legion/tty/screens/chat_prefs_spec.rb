# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/prefs command' do
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
  let(:tmpdir) { Dir.mktmpdir }
  let(:prefs_file) { File.join(tmpdir, 'prefs.json') }

  before do
    allow(reader).to receive(:on)
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
    allow_any_instance_of(described_class).to receive(:prefs_path).and_return(prefs_file)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  subject(:chat) { described_class.new(app, output: output, input_bar: input_bar) }

  describe '/prefs' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/prefs')
    end

    it 'returns :handled' do
      expect(chat.handle_slash_command('/prefs')).to eq(:handled)
    end

    context 'with no arguments' do
      it 'reports "No preferences saved." when file does not exist' do
        chat.handle_slash_command('/prefs')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to eq('No preferences saved.')
      end

      it 'shows saved preferences when they exist' do
        chat.handle_slash_command('/prefs theme purple')
        chat.message_stream.messages.clear
        chat.handle_slash_command('/prefs')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to include('theme')
        expect(content).to include('purple')
      end

      it 'shows "Preferences:" header when prefs exist' do
        chat.handle_slash_command('/prefs foo bar')
        chat.message_stream.messages.clear
        chat.handle_slash_command('/prefs')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to start_with('Preferences:')
      end
    end

    context 'with a key only' do
      it 'reports "No preference set" when key does not exist' do
        chat.handle_slash_command('/prefs unknown_key')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to include("No preference set for 'unknown_key'")
      end

      it 'shows the value when the key exists' do
        chat.handle_slash_command('/prefs mykey myvalue')
        chat.message_stream.messages.clear
        chat.handle_slash_command('/prefs mykey')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to eq('mykey: myvalue')
      end
    end

    context 'with key and value' do
      it 'confirms the preference was set' do
        chat.handle_slash_command('/prefs mykey myvalue')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to eq('Preference set: mykey = myvalue')
      end

      it 'persists the preference to the prefs file' do
        chat.handle_slash_command('/prefs hello world')
        file_content = JSON.parse(File.read(prefs_file))
        expect(file_content['hello']).to eq('world')
      end

      it 'overwrites an existing preference' do
        chat.handle_slash_command('/prefs color on')
        chat.handle_slash_command('/prefs color off')
        file_content = JSON.parse(File.read(prefs_file))
        expect(file_content['color']).to eq('off')
      end

      it 'preserves other preferences when setting a new one' do
        chat.handle_slash_command('/prefs first value1')
        chat.handle_slash_command('/prefs second value2')
        file_content = JSON.parse(File.read(prefs_file))
        expect(file_content['first']).to eq('value1')
        expect(file_content['second']).to eq('value2')
      end

      it 'applies the color pref by delegating to handle_color' do
        expect(chat).to receive(:handle_color).with('/color on')
        chat.handle_slash_command('/prefs color on')
      end

      it 'applies the timestamps pref by delegating to handle_timestamps' do
        expect(chat).to receive(:handle_timestamps).with('/timestamps on')
        chat.handle_slash_command('/prefs timestamps on')
      end

      it 'does not raise for unknown keys' do
        expect { chat.handle_slash_command('/prefs unknown_key anything') }.not_to raise_error
      end
    end

    context 'with corrupted prefs file' do
      before do
        File.write(prefs_file, 'not valid json!!!')
      end

      it 'returns empty prefs gracefully when JSON is invalid' do
        chat.handle_slash_command('/prefs')
        content = chat.message_stream.messages.select { |m| m[:role] == :system }.last[:content]
        expect(content).to eq('No preferences saved.')
      end
    end
  end
end
