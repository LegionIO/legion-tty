# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/app'

RSpec.describe Legion::TTY::App do
  describe 'terminal escape sequence constants' do
    it 'defines ENABLE_ALT_SCREEN' do
      expect(described_class::ENABLE_ALT_SCREEN).to eq("\e[?1049h")
    end

    it 'defines DISABLE_ALT_SCREEN' do
      expect(described_class::DISABLE_ALT_SCREEN).to eq("\e[?1049l")
    end

    it 'defines ENABLE_MOUSE with SGR mode' do
      expect(described_class::ENABLE_MOUSE).to include("\e[?1000h")
      expect(described_class::ENABLE_MOUSE).to include("\e[?1006h")
    end

    it 'defines DISABLE_MOUSE' do
      expect(described_class::DISABLE_MOUSE).to include("\e[?1006l")
    end

    it 'defines SGR_MOUSE_RE for parsing mouse events' do
      expect(described_class::SGR_MOUSE_RE).to be_a(Regexp)
    end
  end

  describe 'KEY_MAP additions' do
    it 'maps ctrl_b (\\x02)' do
      expect(described_class::KEY_MAP["\x02"]).to eq(:ctrl_b)
    end

    it 'maps ctrl_f (\\x06)' do
      expect(described_class::KEY_MAP["\x06"]).to eq(:ctrl_f)
    end
  end

  describe '#parse_sgr_mouse' do
    let(:app) do
      Dir.mktmpdir do |dir|
        return described_class.new(config_dir: dir)
      end
    end

    it 'returns :scroll_up for wheel up event (button 64)' do
      result = app.send(:parse_sgr_mouse, "\e[<64;10;20M")
      expect(result).to eq(:scroll_up)
    end

    it 'returns :scroll_down for wheel down event (button 65)' do
      result = app.send(:parse_sgr_mouse, "\e[<65;10;20M")
      expect(result).to eq(:scroll_down)
    end

    it 'returns nil for regular mouse click (button 0)' do
      result = app.send(:parse_sgr_mouse, "\e[<0;10;20M")
      expect(result).to be_nil
    end

    it 'returns nil for non-mouse input' do
      result = app.send(:parse_sgr_mouse, "\e[A")
      expect(result).to be_nil
    end

    it 'handles mouse release events (lowercase m)' do
      result = app.send(:parse_sgr_mouse, "\e[<64;10;20m")
      expect(result).to eq(:scroll_up)
    end
  end

  describe '#normalize_key' do
    let(:app) do
      Dir.mktmpdir do |dir|
        return described_class.new(config_dir: dir)
      end
    end

    it 'returns :scroll_up for SGR mouse wheel up' do
      result = app.send(:normalize_key, "\e[<64;5;10M")
      expect(result).to eq(:scroll_up)
    end

    it 'returns :scroll_down for SGR mouse wheel down' do
      result = app.send(:normalize_key, "\e[<65;5;10M")
      expect(result).to eq(:scroll_down)
    end

    it 'falls back to KEY_MAP for regular sequences' do
      result = app.send(:normalize_key, "\e[A")
      expect(result).to eq(:up)
    end

    it 'returns raw key when not in KEY_MAP and not a mouse event' do
      result = app.send(:normalize_key, 'x')
      expect(result).to eq('x')
    end
  end

  describe '#dispatch_key with scroll events' do
    let(:app) do
      Dir.mktmpdir do |dir|
        return described_class.new(config_dir: dir)
      end
    end

    before do
      app.send(:setup_hotkeys)
      app.instance_variable_set(:@running, true)
    end

    it 'dispatches :scroll_up directly to the active screen' do
      screen = double('screen')
      allow(screen).to receive(:activate)
      allow(screen).to receive(:needs_input_bar?).and_return(true)
      allow(screen).to receive(:handle_input).with(:scroll_up).and_return(:handled)
      app.screen_manager.push(screen)

      app.send(:dispatch_key, :scroll_up)

      expect(screen).to have_received(:handle_input).with(:scroll_up)
    end

    it 'dispatches :scroll_down directly to the active screen' do
      screen = double('screen')
      allow(screen).to receive(:activate)
      allow(screen).to receive(:needs_input_bar?).and_return(true)
      allow(screen).to receive(:handle_input).with(:scroll_down).and_return(:handled)
      app.screen_manager.push(screen)

      app.send(:dispatch_key, :scroll_down)

      expect(screen).to have_received(:handle_input).with(:scroll_down)
    end
  end
end
