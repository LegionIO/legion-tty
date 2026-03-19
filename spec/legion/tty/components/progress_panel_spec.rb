# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/progress_panel'

RSpec.describe Legion::TTY::Components::ProgressPanel do
  let(:output) { StringIO.new }

  describe '#initialize' do
    it 'sets title and total' do
      panel = described_class.new(title: 'Scanning', total: 10, output: output)
      expect(panel.title).to eq('Scanning')
      expect(panel.total).to eq(10)
      expect(panel.current).to eq(0)
    end
  end

  describe '#advance' do
    it 'increments current by step' do
      panel = described_class.new(title: 'Test', total: 10, output: output)
      panel.advance(3)
      expect(panel.current).to eq(3)
    end

    it 'does not exceed total' do
      panel = described_class.new(title: 'Test', total: 5, output: output)
      panel.advance(10)
      expect(panel.current).to eq(5)
    end

    it 'defaults step to 1' do
      panel = described_class.new(title: 'Test', total: 10, output: output)
      panel.advance
      expect(panel.current).to eq(1)
    end
  end

  describe '#finish' do
    it 'sets current to total' do
      panel = described_class.new(title: 'Test', total: 10, output: output)
      panel.advance(3)
      panel.finish
      expect(panel.current).to eq(10)
    end

    it 'is a no-op when already finished' do
      panel = described_class.new(title: 'Test', total: 5, output: output)
      panel.advance(5)
      panel.finish
      expect(panel.current).to eq(5)
    end
  end

  describe '#finished?' do
    it 'returns false when not done' do
      panel = described_class.new(title: 'Test', total: 10, output: output)
      expect(panel.finished?).to be false
    end

    it 'returns true when current equals total' do
      panel = described_class.new(title: 'Test', total: 10, output: output)
      panel.advance(10)
      expect(panel.finished?).to be true
    end
  end

  describe '#percent' do
    it 'returns percentage as float' do
      panel = described_class.new(title: 'Test', total: 10, output: output)
      panel.advance(5)
      expect(panel.percent).to eq(50.0)
    end

    it 'returns 0 when total is zero' do
      panel = described_class.new(title: 'Test', total: 0, output: output)
      expect(panel.percent).to eq(0)
    end

    it 'rounds to one decimal' do
      panel = described_class.new(title: 'Test', total: 3, output: output)
      panel.advance(1)
      expect(panel.percent).to eq(33.3)
    end
  end

  describe '#render' do
    it 'returns a formatted string with title and bar' do
      panel = described_class.new(title: 'Loading', total: 10, output: output)
      panel.advance(5)
      result = panel.render(width: 60)
      expect(result).to include('Loading')
      expect(result).to include('50.0%')
    end

    it 'works at 0 percent' do
      panel = described_class.new(title: 'Start', total: 10, output: output)
      result = panel.render(width: 60)
      expect(result).to include('0.0%')
    end

    it 'works at 100 percent' do
      panel = described_class.new(title: 'Done', total: 5, output: output)
      panel.finish
      result = panel.render(width: 60)
      expect(result).to include('100.0%')
    end
  end
end
