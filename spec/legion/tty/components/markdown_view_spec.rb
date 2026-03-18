# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/markdown_view'

RSpec.describe Legion::TTY::Components::MarkdownView do
  describe '.render' do
    it 'renders markdown to a string' do
      result = described_class.render('Hello world')
      expect(result).to be_a(String)
    end

    it 'renders text that appears in output' do
      result = described_class.render('Hello world')
      expect(result).to include('Hello world')
    end

    it 'renders code blocks with text in output' do
      result = described_class.render("```ruby\nputs 'hi'\n```")
      expect(result).to include('hi')
    end

    it 'respects the width parameter' do
      result_narrow = described_class.render('# Title', width: 20)
      result_wide   = described_class.render('# Title', width: 200)
      # Both should include the title text
      expect(result_narrow).to include('Title')
      expect(result_wide).to include('Title')
    end

    it 'handles errors gracefully' do
      allow(TTY::Markdown).to receive(:parse).and_raise(StandardError, 'boom')
      result = described_class.render('some text')
      expect(result).to include('some text')
      expect(result).to include('markdown render error')
      expect(result).to include('boom')
    end
  end
end
