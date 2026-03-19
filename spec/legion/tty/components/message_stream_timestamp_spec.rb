# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/message_stream'

RSpec.describe Legion::TTY::Components::MessageStream, 'timestamps' do
  describe '#add_message' do
    it 'stores a timestamp' do
      stream = described_class.new
      stream.add_message(role: :user, content: 'hello')
      expect(stream.messages.last[:timestamp]).to be_a(Time)
    end
  end
end
