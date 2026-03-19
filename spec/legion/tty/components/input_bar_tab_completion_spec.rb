# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/input_bar'

RSpec.describe Legion::TTY::Components::InputBar, 'tab completion' do
  let(:commands) { %w[/help /quit /clear /model /session /cost /export] }
  let(:reader) { double('reader', read_line: '/help') }

  before do
    allow(reader).to receive(:on)
  end

  describe '#complete' do
    it 'returns matching commands for partial input' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.complete('/c')).to eq(['/clear', '/cost'])
    end

    it 'returns single match' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.complete('/he')).to eq(['/help'])
    end

    it 'returns empty for no match' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.complete('/z')).to eq([])
    end

    it 'returns all for exact prefix /' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.complete('/')).to eq(commands.sort)
    end

    it 'returns empty for nil' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.complete(nil)).to eq([])
    end

    it 'returns empty for empty string' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.complete('')).to eq([])
    end
  end

  describe '#completions' do
    it 'exposes the completions list' do
      bar = described_class.new(name: 'Test', reader: reader, completions: commands)
      expect(bar.completions).to eq(commands)
    end

    it 'defaults to empty' do
      bar = described_class.new(name: 'Test', reader: reader)
      expect(bar.completions).to eq([])
    end
  end
end
