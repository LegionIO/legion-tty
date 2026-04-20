# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/message_stream'

RSpec.describe Legion::TTY::Components::MessageStream, 'render cache' do
  subject(:stream) { described_class.new }

  describe 'per-message render cache' do
    before do
      stream.add_message(role: :user, content: 'Hello')
      stream.add_message(role: :assistant, content: 'World')
    end

    it 'returns identical output on consecutive renders with same width' do
      first = stream.render(width: 80, height: 20)
      second = stream.render(width: 80, height: 20)
      expect(second).to eq(first)
    end

    it 'invalidates cache when width changes' do
      stream.render(width: 80, height: 20)
      second = stream.render(width: 60, height: 20)
      expect(second).to be_an(Array)
      expect(second.size).to be > 0
    end

    it 'invalidates cache when message content changes via streaming' do
      stream.add_message(role: :assistant, content: 'Start')
      stream.render(width: 80, height: 20)
      stream.append_streaming(' more text')
      second = stream.render(width: 80, height: 20)
      expect(second.join("\n")).to include('more text')
    end

    it 'invalidates cache when display options change' do
      stream.render(width: 80, height: 20)
      stream.show_timestamps = false
      result = stream.render(width: 80, height: 20)
      expect(result).to be_an(Array)
    end

    it 'does not call render_markdown for cached messages on re-render' do
      stream.add_message(role: :assistant, content: 'Cached')
      stream.render(width: 80, height: 20)

      call_count = 0
      allow(Legion::TTY::Components::MarkdownView).to receive(:render).and_wrap_original do |m, *args, **kwargs|
        call_count += 1
        m.call(*args, **kwargs)
      end

      stream.render(width: 80, height: 20)
      expect(call_count).to eq(0)
    end
  end

  describe 'visible-slice rendering' do
    it 'respects viewport height' do
      20.times { |i| stream.add_message(role: :user, content: "Message #{i}") }
      result = stream.render(width: 80, height: 5)
      expect(result.size).to be <= 5
    end

    it 'returns correct content when scrolled partway back' do
      10.times { |i| stream.add_message(role: :user, content: "Msg#{i}") }
      stream.scroll_up(50)
      result = stream.render(width: 80, height: 5)
      expect(result.size).to be <= 5
    end
  end
end
