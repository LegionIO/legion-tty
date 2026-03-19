# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, '/annotations command' do
  let(:output) { StringIO.new }
  let(:mock_input_bar) do
    instance_double(Legion::TTY::Components::InputBar,
                    prompt_string: '> ',
                    show_thinking: nil,
                    clear_thinking: nil,
                    thinking?: false)
  end
  let(:app) { double('app', config: { name: 'Test', provider: 'claude' }) }

  subject(:chat) { described_class.new(app, output: output, input_bar: mock_input_bar) }

  describe '/annotations' do
    context 'when no messages have annotations' do
      it 'shows "No annotated messages."' do
        chat.message_stream.add_message(role: :user, content: 'hello')
        chat.message_stream.add_message(role: :assistant, content: 'world')

        result = chat.handle_slash_command('/annotations')
        expect(result).to eq(:handled)

        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No annotated messages.')
      end

      it 'returns :handled when message stream is empty' do
        result = chat.handle_slash_command('/annotations')
        expect(result).to eq(:handled)
      end
    end

    context 'when messages have annotations' do
      it 'lists annotated messages with index and annotation text' do
        chat.message_stream.add_message(role: :user, content: 'question')
        chat.message_stream.add_message(role: :assistant, content: 'answer')

        annotated_msg = chat.message_stream.messages[1]
        annotated_msg[:annotations] = [{ text: 'important note', timestamp: '2026-01-01T00:00:00+00:00' }]

        result = chat.handle_slash_command('/annotations')
        expect(result).to eq(:handled)

        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        content = msgs.last[:content]
        expect(content).to include('Annotations:')
        expect(content).to include('important note')
      end

      it 'includes message index in the output' do
        chat.message_stream.add_message(role: :user, content: 'first')
        chat.message_stream.add_message(role: :assistant, content: 'second')

        chat.message_stream.messages[1][:annotations] = [
          { text: 'my annotation', timestamp: '2026-01-01T00:00:00+00:00' }
        ]

        chat.handle_slash_command('/annotations')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('[1]')
      end

      it 'includes the message role in the output' do
        chat.message_stream.add_message(role: :assistant, content: 'some response')
        chat.message_stream.messages[0][:annotations] = [
          { text: 'note', timestamp: '2026-01-01T00:00:00+00:00' }
        ]

        chat.handle_slash_command('/annotations')
        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to include('assistant')
      end
    end

    context 'when messages have empty annotations array' do
      it 'ignores messages with empty annotations array' do
        chat.message_stream.add_message(role: :user, content: 'hello')
        chat.message_stream.messages[0][:annotations] = []

        result = chat.handle_slash_command('/annotations')
        expect(result).to eq(:handled)

        msgs = chat.message_stream.messages.select { |m| m[:role] == :system }
        expect(msgs.last[:content]).to eq('No annotated messages.')
      end
    end

    it 'includes /annotations in SLASH_COMMANDS' do
      expect(described_class::SLASH_COMMANDS).to include('/annotations')
    end
  end
end
