# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/notify'

RSpec.describe Legion::TTY::Notify do
  subject(:notify) { described_class }

  # Restore ENV after each example
  around do |example|
    orig_term_program = ENV.fetch('TERM_PROGRAM', nil)
    orig_term = ENV.fetch('TERM', nil)
    example.run
    ENV['TERM_PROGRAM'] = orig_term_program
    ENV['TERM'] = orig_term
  end

  describe '.detect_terminal' do
    it 'detects iTerm2 from TERM_PROGRAM=iTerm.app' do
      ENV['TERM_PROGRAM'] = 'iTerm.app'
      ENV['TERM'] = ''
      expect(notify.detect_terminal).to eq('iterm2')
    end

    it 'detects kitty from TERM_PROGRAM=kitty' do
      ENV['TERM_PROGRAM'] = 'kitty'
      ENV['TERM'] = ''
      expect(notify.detect_terminal).to eq('kitty')
    end

    it 'detects kitty from TERM=xterm-kitty' do
      ENV['TERM_PROGRAM'] = ''
      ENV['TERM'] = 'xterm-kitty'
      expect(notify.detect_terminal).to eq('kitty')
    end

    it 'detects Ghostty from TERM_PROGRAM=ghostty' do
      ENV['TERM_PROGRAM'] = 'ghostty'
      ENV['TERM'] = ''
      expect(notify.detect_terminal).to eq('ghostty')
    end

    it 'is case-insensitive for TERM_PROGRAM' do
      ENV['TERM_PROGRAM'] = 'KITTY'
      ENV['TERM'] = ''
      expect(notify.detect_terminal).to eq('kitty')
    end

    it 'returns unknown for unrecognized terminal on neither platform' do
      ENV['TERM_PROGRAM'] = 'some_unknown_terminal'
      ENV['TERM'] = 'xterm-256color'
      # Depending on CI platform, result is 'linux', 'macos', or 'unknown'
      result = notify.detect_terminal
      expect(%w[linux macos unknown]).to include(result)
    end
  end

  describe '.send' do
    before do
      # Stub Legion::Settings to return enabled: true
      stub_const('Legion::Settings', Module.new do
        def self.[](key)
          { terminal: { enabled: true, backend: 'bell' } } if key == :notifications
        end
      end)
    end

    it 'writes to $stdout for bell backend' do
      ENV['TERM_PROGRAM'] = 'unknown_term'
      ENV['TERM'] = 'dumb'
      allow(notify).to receive(:configured_backend).and_return('bell')
      expect($stdout).to receive(:print).with("\a")
      expect($stdout).to receive(:flush)
      notify.send('Test message')
    end

    it 'does not raise with default arguments' do
      allow(notify).to receive(:enabled?).and_return(true)
      allow(notify).to receive(:dispatch)
      expect { notify.send('hello') }.not_to raise_error
    end

    it 'accepts a custom title keyword argument' do
      allow(notify).to receive(:enabled?).and_return(true)
      allow(notify).to receive(:dispatch)
      expect { notify.send('hello', title: 'MyApp') }.not_to raise_error
    end

    it 'does nothing when disabled via settings' do
      allow(notify).to receive(:enabled?).and_return(false)
      expect(notify).not_to receive(:dispatch)
      notify.send('silent')
    end
  end

  describe 'backend dispatch' do
    describe 'iterm2 backend' do
      it 'writes OSC 9 escape sequence to stdout' do
        allow(notify).to receive(:enabled?).and_return(true)
        allow(notify).to receive(:configured_backend).and_return('iterm2')
        expect($stdout).to receive(:print).with("\e]9;hello\a")
        expect($stdout).to receive(:flush)
        notify.send('hello', title: 'T')
      end
    end

    describe 'ghostty backend' do
      it 'writes OSC 99 escape sequence to stdout' do
        allow(notify).to receive(:enabled?).and_return(true)
        allow(notify).to receive(:configured_backend).and_return('ghostty')
        expect($stdout).to receive(:print).with(a_string_starting_with("\e]99;"))
        expect($stdout).to receive(:flush)
        notify.send('hello', title: 'T')
      end
    end

    describe 'kitty backend' do
      it 'spawns kitten notify' do
        allow(notify).to receive(:enabled?).and_return(true)
        allow(notify).to receive(:configured_backend).and_return('kitty')
        expect(Kernel).to receive(:system).with('kitten', 'notify', '--title', 'T', 'hello')
        notify.send('hello', title: 'T')
      end
    end

    describe 'notify_send backend' do
      it 'spawns notify-send' do
        allow(notify).to receive(:enabled?).and_return(true)
        allow(notify).to receive(:configured_backend).and_return('notify_send')
        expect(Kernel).to receive(:system).with('notify-send', 'T', 'hello')
        notify.send('hello', title: 'T')
      end
    end

    describe 'osascript backend' do
      it 'spawns osascript with display notification' do
        allow(notify).to receive(:enabled?).and_return(true)
        allow(notify).to receive(:configured_backend).and_return('osascript')
        expect(Kernel).to receive(:system).with(
          'osascript', '-e',
          'display notification "hello" with title "T"'
        )
        notify.send('hello', title: 'T')
      end
    end

    describe 'fallback bell backend' do
      it 'falls back to bell when the primary dispatch raises' do
        allow(notify).to receive(:enabled?).and_return(true)
        allow(notify).to receive(:configured_backend).and_return('kitty')
        # kitty uses Kernel.system — make it raise to trigger rescue
        allow(Kernel).to receive(:system).and_raise(StandardError, 'kitten not found')
        # bell writes \a to stdout
        bell_output = +''
        allow($stdout).to receive(:print) { |s| bell_output << s.to_s }
        allow($stdout).to receive(:flush)
        notify.send('hello', title: 'T')
        expect(bell_output).to include("\a")
      end
    end
  end

  describe 'BACKENDS constant' do
    it 'lists all supported backends' do
      expect(described_class::BACKENDS).to include('iterm2', 'kitty', 'ghostty', 'notify_send', 'osascript', 'bell')
    end
  end
end
