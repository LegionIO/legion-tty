# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/digital_rain'

RSpec.describe Legion::TTY::Components::DigitalRain do
  subject(:rain) { described_class.new(width: 20, height: 10, density: 0.5) }

  describe '#initialize' do
    it 'creates columns based on width and density' do
      # density 0.5 on width 20 => ~10 columns
      expect(rain.columns.size).to be_between(1, 20)
    end

    it 'each column has required keys' do
      rain.columns.each do |col|
        expect(col).to have_key(:x)
        expect(col).to have_key(:y)
        expect(col).to have_key(:speed)
        expect(col).to have_key(:length)
        expect(col).to have_key(:chars)
      end
    end

    it 'column x positions are within width' do
      rain.columns.each do |col|
        expect(col[:x]).to be_between(0, 19)
      end
    end
  end

  describe '#tick' do
    it 'advances column y positions by speed' do
      initial_ys = rain.columns.map { |c| c[:y] }
      rain.tick
      new_ys = rain.columns.map { |c| c[:y] }
      expect(new_ys).not_to eq(initial_ys)
    end

    it 'resets columns that fall off the bottom' do
      # Force a column off the bottom
      rain.columns.first[:y] = rain.height + 20
      rain.tick
      expect(rain.columns.first[:y]).to be <= rain.height
    end
  end

  describe '#render_frame' do
    it 'returns an array of strings' do
      result = rain.render_frame
      expect(result).to be_an(Array)
    end

    it 'returns rows matching height' do
      result = rain.render_frame
      expect(result.size).to eq(rain.height)
    end

    it 'each row is a string' do
      rain.render_frame.each do |row|
        expect(row).to be_a(String)
      end
    end
  end

  describe '#done?' do
    it 'returns false initially' do
      expect(rain.done?).to be false
    end
  end

  describe '.extension_names' do
    it 'returns an array' do
      expect(described_class.extension_names).to be_an(Array)
    end

    it 'returns non-empty array (fallback at minimum)' do
      expect(described_class.extension_names).not_to be_empty
    end

    it 'all entries are strings' do
      described_class.extension_names.each do |name|
        expect(name).to be_a(String)
      end
    end
  end

  describe 'FADE_SHADES' do
    it 'is an array of color symbols' do
      expect(described_class::FADE_SHADES).to be_an(Array)
      expect(described_class::FADE_SHADES).not_to be_empty
    end
  end
end
