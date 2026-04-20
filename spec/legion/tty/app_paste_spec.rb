# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'legion/tty/app'

RSpec.describe Legion::TTY::App, 'bracketed paste' do
  let(:app) do
    Dir.mktmpdir do |dir|
      return described_class.new(config_dir: dir)
    end
  end

  describe 'paste constants' do
    it 'defines ENABLE_BRACKETED_PASTE' do
      expect(described_class::ENABLE_BRACKETED_PASTE).to eq("\e[?2004h")
    end

    it 'defines DISABLE_BRACKETED_PASTE' do
      expect(described_class::DISABLE_BRACKETED_PASTE).to eq("\e[?2004l")
    end
  end

  describe '#normalize_key with paste event' do
    it 'returns a paste hash unchanged' do
      paste_event = { paste: "line1\nline2" }
      result = app.send(:normalize_key, paste_event)
      expect(result).to eq(paste_event)
    end
  end

  describe '#dispatch_key with paste event' do
    before do
      app.send(:setup_hotkeys)
      app.instance_variable_set(:@running, true)
    end

    it 'routes paste events to input bar on input-enabled screens' do
      input_bar = instance_double(Legion::TTY::Components::InputBar)
      allow(input_bar).to receive(:handle_key).with({ paste: 'hello' }).and_return(:handled)
      allow(input_bar).to receive(:cursor_column).and_return(10)
      app.instance_variable_set(:@input_bar, input_bar)

      screen = double('screen')
      allow(screen).to receive(:activate)
      allow(screen).to receive(:needs_input_bar?).and_return(true)
      app.screen_manager.push(screen)

      app.send(:dispatch_key, { paste: 'hello' })
      expect(input_bar).to have_received(:handle_key).with({ paste: 'hello' })
    end
  end
end
