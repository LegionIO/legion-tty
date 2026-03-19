# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/message_stream'

RSpec.describe Legion::TTY::Components::MessageStream, 'filter support' do
  subject(:stream) { described_class.new }

  describe '#filter accessor' do
    it 'defaults to nil' do
      expect(stream.filter).to be_nil
    end

    it 'can be set to a filter hash' do
      stream.filter = { type: :role, value: 'user' }
      expect(stream.filter).to eq({ type: :role, value: 'user' })
    end

    it 'can be cleared by setting to nil' do
      stream.filter = { type: :role, value: 'user' }
      stream.filter = nil
      expect(stream.filter).to be_nil
    end
  end

  describe '#filtered_messages' do
    before do
      stream.add_message(role: :user, content: 'user message')
      stream.add_message(role: :assistant, content: 'assistant message')
      stream.add_message(role: :system, content: 'system message')
    end

    it 'returns all messages when filter is nil' do
      expect(stream.send(:filtered_messages).size).to eq(3)
    end

    it 'returns all messages when filter is nil after being set and cleared' do
      stream.filter = { type: :role, value: 'user' }
      stream.filter = nil
      expect(stream.send(:filtered_messages).size).to eq(3)
    end

    context 'with role filter' do
      it 'returns only user messages' do
        stream.filter = { type: :role, value: 'user' }
        msgs = stream.send(:filtered_messages)
        expect(msgs.map { |m| m[:role] }).to all(eq(:user))
      end

      it 'returns only assistant messages' do
        stream.filter = { type: :role, value: 'assistant' }
        msgs = stream.send(:filtered_messages)
        expect(msgs.map { |m| m[:role] }).to all(eq(:assistant))
      end

      it 'returns only system messages' do
        stream.filter = { type: :role, value: 'system' }
        msgs = stream.send(:filtered_messages)
        expect(msgs.map { |m| m[:role] }).to all(eq(:system))
      end

      it 'returns empty array when no messages match role' do
        stream.filter = { type: :role, value: 'tool' }
        expect(stream.send(:filtered_messages)).to be_empty
      end
    end

    context 'with tag filter' do
      before do
        stream.messages[0][:tags] = %w[work important]
        stream.messages[1][:tags] = ['work']
      end

      it 'returns only messages with the given tag' do
        stream.filter = { type: :tag, value: 'work' }
        msgs = stream.send(:filtered_messages)
        expect(msgs.size).to eq(2)
      end

      it 'filters to single message with specific tag' do
        stream.filter = { type: :tag, value: 'important' }
        msgs = stream.send(:filtered_messages)
        expect(msgs.size).to eq(1)
        expect(msgs.first[:content]).to eq('user message')
      end

      it 'returns empty array when no messages have the tag' do
        stream.filter = { type: :tag, value: 'nonexistent' }
        expect(stream.send(:filtered_messages)).to be_empty
      end

      it 'returns empty when message has no tags key' do
        stream.filter = { type: :tag, value: 'anything' }
        stream.messages[0].delete(:tags)
        stream.messages[1].delete(:tags)
        expect(stream.send(:filtered_messages)).to be_empty
      end
    end

    context 'with pinned filter' do
      it 'returns only pinned messages' do
        stream.messages[0][:pinned] = true
        stream.filter = { type: :pinned }
        msgs = stream.send(:filtered_messages)
        expect(msgs.size).to eq(1)
        expect(msgs.first[:content]).to eq('user message')
      end

      it 'returns empty array when no messages are pinned' do
        stream.filter = { type: :pinned }
        expect(stream.send(:filtered_messages)).to be_empty
      end

      it 'returns multiple pinned messages' do
        stream.messages[0][:pinned] = true
        stream.messages[2][:pinned] = true
        stream.filter = { type: :pinned }
        expect(stream.send(:filtered_messages).size).to eq(2)
      end
    end

    context 'with unknown filter type' do
      it 'returns all messages as fallback' do
        stream.filter = { type: :unknown_type }
        expect(stream.send(:filtered_messages).size).to eq(3)
      end
    end
  end

  describe '#render with filter applied' do
    before do
      stream.add_message(role: :user, content: 'user message')
      stream.add_message(role: :assistant, content: 'assistant message')
    end

    it 'only renders filtered messages when role filter is set' do
      stream.filter = { type: :role, value: 'user' }
      result = stream.render(width: 80, height: 20).join("\n")
      expect(result).to include('user message')
      expect(result).not_to include('assistant message')
    end

    it 'renders all messages when filter is nil' do
      stream.filter = nil
      result = stream.render(width: 80, height: 20).join("\n")
      expect(result).to include('user message')
      expect(result).to include('assistant message')
    end
  end
end
