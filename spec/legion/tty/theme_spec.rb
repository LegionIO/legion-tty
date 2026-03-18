# frozen_string_literal: true

# rubocop:disable Naming/VariableNumber
require 'spec_helper'
require 'legion/tty/theme'

RSpec.describe Legion::TTY::Theme do
  describe 'PALETTE' do
    it 'has exactly 17 entries' do
      expect(described_class::PALETTE.size).to eq(17)
    end

    it 'each entry is an RGB triple with values 0-255' do
      described_class::PALETTE.each_value do |rgb|
        expect(rgb.size).to eq(3)
        rgb.each { |v| expect(v).to be_between(0, 255) }
      end
    end
  end

  describe 'SEMANTIC' do
    it 'maps to palette symbols or RGB arrays' do
      described_class::SEMANTIC.each_value do |val|
        if val.is_a?(Symbol)
          expect(described_class::PALETTE).to have_key(val)
        else
          expect(val).to be_an(Array)
          expect(val.size).to eq(3)
        end
      end
    end
  end

  describe '.c' do
    it 'wraps text with ANSI escape codes for a palette color' do
      result = described_class.c(:purple_9, 'hello')
      expect(result).to start_with("\e[38;2;")
      expect(result).to include('hello')
      expect(result).to end_with("\e[0m")
    end

    it 'embeds the correct RGB values for a palette color' do
      rgb = described_class::PALETTE[:purple_9]
      result = described_class.c(:purple_9, 'test')
      expect(result).to include("38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m")
    end

    it 'works with semantic color names that reference palette symbols' do
      result = described_class.c(:primary, 'hi')
      expect(result).to start_with("\e[38;2;")
      expect(result).to include('hi')
      expect(result).to end_with("\e[0m")
    end

    it 'works with semantic color names that are direct RGB arrays' do
      result = described_class.c(:success, 'ok')
      expect(result).to include('38;2;0;200;83m')
      expect(result).to include('ok')
    end

    it 'returns plain text for unknown color names' do
      result = described_class.c(:nonexistent, 'plain')
      expect(result).to eq('plain')
    end
  end
end
# rubocop:enable Naming/VariableNumber
