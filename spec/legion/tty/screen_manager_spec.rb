# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/base'
require 'legion/tty/screen_manager'

RSpec.describe Legion::TTY::ScreenManager do
  subject(:manager) { described_class.new }

  def make_screen
    instance_double(Legion::TTY::Screens::Base,
                    activate: nil, deactivate: nil, teardown: nil)
  end

  describe '#push' do
    it 'activates the pushed screen' do
      screen = make_screen
      expect(screen).to receive(:activate)
      manager.push(screen)
    end

    it 'deactivates the previous screen when pushing a new one' do
      first = make_screen
      second = make_screen
      manager.push(first)
      expect(first).to receive(:deactivate)
      manager.push(second)
    end

    it 'sets the pushed screen as active' do
      screen = make_screen
      manager.push(screen)
      expect(manager.active_screen).to eq(screen)
    end
  end

  describe '#pop' do
    it 'tears down the top screen' do
      first = make_screen
      second = make_screen
      manager.push(first)
      manager.push(second)
      expect(second).to receive(:teardown)
      manager.pop
    end

    it 'reactivates the screen below after pop' do
      first = make_screen
      second = make_screen
      manager.push(first)
      manager.push(second)
      expect(first).to receive(:activate)
      manager.pop
    end

    it 'does not pop when only one screen remains' do
      screen = make_screen
      manager.push(screen)
      expect(screen).not_to receive(:teardown)
      manager.pop
      expect(manager.active_screen).to eq(screen)
    end

    it 'makes the previous screen active after pop' do
      first = make_screen
      second = make_screen
      manager.push(first)
      manager.push(second)
      manager.pop
      expect(manager.active_screen).to eq(first)
    end
  end

  describe '#active_screen' do
    it 'returns nil when stack is empty' do
      expect(manager.active_screen).to be_nil
    end

    it 'returns the top of the stack' do
      first = make_screen
      second = make_screen
      manager.push(first)
      manager.push(second)
      expect(manager.active_screen).to eq(second)
    end
  end

  describe '#show_overlay and #dismiss_overlay' do
    it 'sets the overlay' do
      overlay = double('overlay')
      manager.show_overlay(overlay)
      expect(manager.overlay).to eq(overlay)
    end

    it 'clears the overlay on dismiss' do
      overlay = double('overlay')
      manager.show_overlay(overlay)
      manager.dismiss_overlay
      expect(manager.overlay).to be_nil
    end
  end

  describe '#enqueue and #drain_queue' do
    it 'drains queued updates in order' do
      manager.enqueue(:update_a)
      manager.enqueue(:update_b)
      expect(manager.drain_queue).to eq(%i[update_a update_b])
    end

    it 'returns empty array when queue is empty' do
      expect(manager.drain_queue).to eq([])
    end
  end

  describe '#teardown_all' do
    it 'tears down all screens' do
      first = make_screen
      second = make_screen
      manager.push(first)
      manager.push(second)
      expect(first).to receive(:teardown)
      expect(second).to receive(:teardown)
      manager.teardown_all
    end

    it 'clears the stack after teardown' do
      screen = make_screen
      manager.push(screen)
      manager.teardown_all
      expect(manager.active_screen).to be_nil
    end
  end
end
