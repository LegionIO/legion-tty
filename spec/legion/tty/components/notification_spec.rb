# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/notification'

RSpec.describe Legion::TTY::Components::Notification do
  describe '#initialize' do
    it 'stores message and level' do
      n = described_class.new(message: 'hello', level: :success)
      expect(n.message).to eq('hello')
      expect(n.level).to eq(:success)
    end

    it 'defaults to :info level' do
      n = described_class.new(message: 'test')
      expect(n.level).to eq(:info)
    end

    it 'falls back to :info for unknown levels' do
      n = described_class.new(message: 'test', level: :unknown)
      expect(n.level).to eq(:info)
    end
  end

  describe '#expired?' do
    it 'returns false when fresh' do
      n = described_class.new(message: 'test', ttl: 60)
      expect(n.expired?).to be false
    end

    it 'returns true when past TTL' do
      n = described_class.new(message: 'test', ttl: 0)
      sleep 0.01
      expect(n.expired?).to be true
    end
  end

  describe '#render' do
    it 'returns a string with icon and message' do
      n = described_class.new(message: 'Connected', level: :success)
      result = n.render(width: 40)
      expect(result).to include('Connected')
    end

    it 'works with all levels' do
      Legion::TTY::Components::Notification::LEVELS.each do |level|
        n = described_class.new(message: 'test', level: level)
        expect(n.render).to be_a(String)
      end
    end
  end
end
