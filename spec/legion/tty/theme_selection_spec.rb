# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/theme'

RSpec.describe Legion::TTY::Theme do
  after { described_class.reset_theme }

  describe '.current_theme' do
    it 'defaults to :purple' do
      expect(described_class.current_theme).to eq(:purple)
    end
  end

  describe '.switch' do
    it 'switches to a valid theme' do
      expect(described_class.switch(:green)).to be true
      expect(described_class.current_theme).to eq(:green)
    end

    it 'returns false for unknown theme' do
      expect(described_class.switch(:neon)).to be false
      expect(described_class.current_theme).to eq(:purple)
    end

    it 'accepts string names' do
      expect(described_class.switch('blue')).to be true
      expect(described_class.current_theme).to eq(:blue)
    end
  end

  describe '.available_themes' do
    it 'returns all theme names' do
      themes = described_class.available_themes
      expect(themes).to include(:purple, :green, :blue, :amber)
    end
  end

  describe '.c' do
    it 'returns colored text for semantic names' do
      result = described_class.c(:primary, 'hello')
      expect(result).to include('hello')
      expect(result).to include("\e[38;2;")
    end

    it 'uses the active theme colors' do
      purple_result = described_class.c(:primary, 'test')
      described_class.switch(:green)
      green_result = described_class.c(:primary, 'test')
      expect(purple_result).not_to eq(green_result)
    end

    it 'returns plain text for unknown names' do
      result = described_class.c(:nonexistent, 'plain')
      expect(result).to eq('plain')
    end
  end

  describe '.reset_theme' do
    it 'resets to purple' do
      described_class.switch(:amber)
      described_class.reset_theme
      expect(described_class.current_theme).to eq(:purple)
    end
  end

  describe 'backward compatibility' do
    it 'provides PALETTE constant' do
      expect(described_class::PALETTE).to be_a(Hash)
      expect(described_class::PALETTE.keys.first.to_s).to start_with('purple_')
    end

    it 'provides SEMANTIC constant' do
      expect(described_class::SEMANTIC).to be_a(Hash)
      expect(described_class::SEMANTIC).to have_key(:primary)
    end
  end
end
