# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/status_bar'

RSpec.describe Legion::TTY::Components::StatusBar, 'scroll hint' do
  subject(:bar) { described_class.new }

  describe 'scroll_segment with hint' do
    it 'shows up-arrow hint when scrolled away from bottom' do
      bar.update(scroll: { current: 5, total: 20, visible: 10 })
      result = bar.render(width: 120)
      plain = result.gsub(/\e\[[0-9;]*m/, '')
      expect(plain).to include('scroll')
    end

    it 'includes up and down arrows when offset is positive' do
      bar.update(scroll: { current: 5, total: 20, visible: 10 })
      result = bar.render(width: 120)
      expect(result).to include("\u2191")
      expect(result).to include("\u2193")
    end

    it 'shows only up arrow when at bottom (offset 0)' do
      bar.update(scroll: { current: 0, total: 20, visible: 10 })
      result = bar.render(width: 120)
      expect(result).to include("\u2191")
      expect(result).not_to include("\u2193")
    end

    it 'does not show scroll hint when all content is visible' do
      bar.update(scroll: { current: 0, total: 5, visible: 10 })
      result = bar.render(width: 120)
      plain = result.gsub(/\e\[[0-9;]*m/, '')
      expect(plain).not_to include('scroll')
    end
  end
end
