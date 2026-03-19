# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tempfile'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/fav and /favs commands' do
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

  # Use a temp file so tests don't pollute ~/.legionio/favorites.json
  let(:tmp_favs) { Tempfile.new(['favorites', '.json']) }

  before do
    allow(chat).to receive(:favorites_file).and_return(tmp_favs.path)
    tmp_favs.write('[]')
    tmp_favs.flush
    tmp_favs.rewind
  end

  after { tmp_favs.unlink }

  describe '/fav' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/fav')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/fav')
      expect(result).to eq(:handled)
    end

    context 'when no assistant message exists' do
      it 'reports "No message to favorite."' do
        chat.handle_slash_command('/fav')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No message to favorite.')
      end
    end

    context 'when an assistant message exists' do
      before do
        chat.message_stream.add_message(role: :assistant, content: 'This is the answer')
      end

      it 'favorites the last assistant message' do
        chat.handle_slash_command('/fav')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('Favorited')
      end

      it 'shows a preview of the favorited message' do
        chat.handle_slash_command('/fav')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('This is the answer')
      end

      it 'persists the favorite to disk' do
        chat.handle_slash_command('/fav')
        tmp_favs.rewind
        data = JSON.parse(tmp_favs.read)
        expect(data).not_to be_empty
        expect(data.first['content']).to eq('This is the answer')
      end

      it 'stores role in persisted entry' do
        chat.handle_slash_command('/fav')
        tmp_favs.rewind
        data = JSON.parse(tmp_favs.read)
        expect(data.first['role']).to eq('assistant')
      end

      it 'stores saved_at in persisted entry' do
        chat.handle_slash_command('/fav')
        tmp_favs.rewind
        data = JSON.parse(tmp_favs.read)
        expect(data.first['saved_at']).not_to be_nil
      end

      it 'stores session name in persisted entry' do
        chat.handle_slash_command('/fav')
        tmp_favs.rewind
        data = JSON.parse(tmp_favs.read)
        expect(data.first['session']).to eq('default')
      end
    end

    context 'with an index argument' do
      it 'favorites the message at the given index' do
        chat.message_stream.add_message(role: :user, content: 'user question')
        chat.message_stream.add_message(role: :assistant, content: 'assistant reply')
        chat.handle_slash_command('/fav 0')
        tmp_favs.rewind
        data = JSON.parse(tmp_favs.read)
        expect(data.first['content']).to eq('user question')
      end

      it 'reports "No message to favorite." for out-of-range index' do
        chat.handle_slash_command('/fav 99')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No message to favorite.')
      end
    end

    it 'accumulates multiple favorites' do
      chat.message_stream.add_message(role: :assistant, content: 'first reply')
      chat.handle_slash_command('/fav')
      chat.message_stream.add_message(role: :assistant, content: 'second reply')
      chat.handle_slash_command('/fav')
      tmp_favs.rewind
      data = JSON.parse(tmp_favs.read)
      expect(data.size).to eq(2)
    end
  end

  describe '/favs' do
    it 'is included in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/favs')
    end

    it 'returns :handled' do
      result = chat.handle_slash_command('/favs')
      expect(result).to eq(:handled)
    end

    context 'when no favorites exist' do
      it 'reports "No favorites saved."' do
        chat.handle_slash_command('/favs')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No favorites saved.')
      end
    end

    context 'when favorites exist on disk' do
      before do
        favs = [
          { role: 'assistant', content: 'Favorite one', saved_at: '2026-01-01T00:00:00Z', session: 'default' },
          { role: 'assistant', content: 'Favorite two', saved_at: '2026-01-02T00:00:00Z', session: 'other' }
        ]
        tmp_favs.rewind
        tmp_favs.truncate(0)
        tmp_favs.write(JSON.generate(favs))
        tmp_favs.flush
        tmp_favs.rewind
      end

      it 'shows all favorites' do
        chat.handle_slash_command('/favs')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Favorite one')
        expect(content).to include('Favorite two')
      end

      it 'shows numbered entries' do
        chat.handle_slash_command('/favs')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('1.')
        expect(content).to include('2.')
      end

      it 'shows the total count' do
        chat.handle_slash_command('/favs')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('2')
      end

      it 'includes saved_at in each entry' do
        chat.handle_slash_command('/favs')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('2026-01-01')
      end
    end

    context 'when favorites file is corrupt' do
      before do
        tmp_favs.rewind
        tmp_favs.truncate(0)
        tmp_favs.write('not valid json{{')
        tmp_favs.flush
        tmp_favs.rewind
      end

      it 'gracefully shows "No favorites saved."' do
        chat.handle_slash_command('/favs')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No favorites saved.')
      end
    end
  end
end
