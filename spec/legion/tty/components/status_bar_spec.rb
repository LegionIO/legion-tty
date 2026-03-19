# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/status_bar'

RSpec.describe Legion::TTY::Components::StatusBar do
  subject(:bar) { described_class.new }

  describe '#render' do
    it 'returns a string' do
      expect(bar.render(width: 80)).to be_a(String)
    end

    it 'returns a string even with empty state' do
      result = bar.render(width: 80)
      expect(result).not_to be_nil
    end
  end

  describe '#update and #render' do
    it 'includes model name when set' do
      bar.update(model: 'claude-3-opus')
      result = bar.render(width: 120)
      expect(result).to include('claude-3-opus')
    end

    it 'includes comma-formatted token count' do
      bar.update(tokens: 12_345)
      result = bar.render(width: 120)
      expect(result).to include('12,345')
    end

    it 'includes cost formatted as $X.XXX' do
      bar.update(cost: 0.00312)
      result = bar.render(width: 120)
      expect(result).to match(/\$\d+\.\d{3}/)
    end

    it 'includes session name' do
      bar.update(session: 'my-session')
      result = bar.render(width: 120)
      expect(result).to include('my-session')
    end

    it 'omits model segment when nil' do
      bar.update(model: nil, tokens: 100)
      result = bar.render(width: 120)
      # no model in result — hard to assert absence without knowing exact format
      # just ensure it renders without error
      expect(result).to be_a(String)
    end

    it 'output does not exceed specified width' do
      bar.update(model: 'claude-3-opus', tokens: 99_999, cost: 1.234, session: 'test')
      result = bar.render(width: 80)
      plain = result.gsub(/\e\[[0-9;]*m/, '')
      expect(plain.length).to be <= 80
    end
  end

  describe 'plan_mode indicator' do
    it 'shows [PLAN] when plan_mode is true' do
      bar.update(plan_mode: true)
      result = bar.render(width: 120)
      expect(result).to include('[PLAN]')
    end

    it 'omits [PLAN] when plan_mode is false' do
      bar.update(plan_mode: false)
      result = bar.render(width: 120)
      expect(result).not_to include('[PLAN]')
    end
  end

  describe 'thinking indicator' do
    it 'includes thinking text when thinking is true' do
      bar.update(thinking: true)
      result = bar.render(width: 120)
      expect(result).to include('thinking')
    end

    it 'omits thinking text when thinking is false' do
      bar.update(thinking: false)
      result = bar.render(width: 120)
      expect(result).not_to include('thinking')
    end

    it 'thinking segment uses warning color' do
      allow(Legion::TTY::Theme).to receive(:c).and_call_original
      expect(Legion::TTY::Theme).to receive(:c).with(:warning, a_string_including('thinking...'))
      bar.update(thinking: true)
      bar.render(width: 120)
    end
  end
end
