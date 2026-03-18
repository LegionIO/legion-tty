# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/tool_panel'

RSpec.describe Legion::TTY::Components::ToolPanel do
  let(:running_panel) do
    described_class.new(name: 'search_files', args: { query: 'ruby' }, status: :running)
  end

  let(:complete_panel) do
    described_class.new(
      name: 'read_file',
      args: { path: '/tmp/foo.rb' },
      status: :complete,
      duration: 0.42,
      result: 'file contents here'
    )
  end

  let(:failed_panel) do
    described_class.new(
      name: 'write_file',
      args: { path: '/tmp/bar.rb' },
      status: :failed,
      error: 'permission denied'
    )
  end

  describe '#render' do
    it 'renders running state with tool name' do
      result = running_panel.render(width: 80)
      expect(result).to include('search_files')
    end

    it 'running panel shows running icon' do
      result = running_panel.render(width: 80)
      expect(result).to include("\u27F3")
    end

    it 'renders completed state with duration' do
      result = complete_panel.render(width: 80)
      expect(result).to include('0.42')
    end

    it 'complete panel shows complete icon' do
      result = complete_panel.render(width: 80)
      expect(result).to include("\u2713")
    end

    it 'renders expanded state with result text' do
      complete_panel.expand
      result = complete_panel.render(width: 80)
      expect(result).to include('file contents here')
    end

    it 'collapsed complete panel does not show result' do
      result = complete_panel.render(width: 80)
      expect(result).not_to include('file contents here')
    end

    it 'renders failed state with error text' do
      result = failed_panel.render(width: 80)
      expect(result).to include('permission denied')
    end

    it 'failed panel shows failed icon' do
      result = failed_panel.render(width: 80)
      expect(result).to include("\u2717")
    end
  end

  describe '#expanded?' do
    it 'defaults false for complete' do
      expect(complete_panel.expanded?).to be false
    end

    it 'defaults true for failed' do
      expect(failed_panel.expanded?).to be true
    end

    it 'defaults false for running' do
      expect(running_panel.expanded?).to be false
    end
  end

  describe '#expand / #collapse / #toggle' do
    it 'expand sets expanded to true' do
      complete_panel.expand
      expect(complete_panel.expanded?).to be true
    end

    it 'collapse sets expanded to false' do
      failed_panel.collapse
      expect(failed_panel.expanded?).to be false
    end

    it 'toggle switches expanded state' do
      expect(complete_panel.expanded?).to be false
      complete_panel.toggle
      expect(complete_panel.expanded?).to be true
      complete_panel.toggle
      expect(complete_panel.expanded?).to be false
    end
  end
end
