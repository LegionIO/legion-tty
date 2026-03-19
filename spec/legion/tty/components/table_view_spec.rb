# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/components/table_view'

RSpec.describe Legion::TTY::Components::TableView do
  describe '.render' do
    let(:headers) { %w[Name Status] }
    let(:rows) { [%w[service-a running], %w[service-b stopped]] }

    it 'returns a string' do
      result = described_class.render(headers: headers, rows: rows)
      expect(result).to be_a(String)
    end

    it 'includes header values in output' do
      result = described_class.render(headers: headers, rows: rows)
      expect(result).to include('Name')
      expect(result).to include('Status')
    end

    it 'includes row values in output' do
      result = described_class.render(headers: headers, rows: rows)
      expect(result).to include('service-a')
      expect(result).to include('running')
    end

    it 'accepts a custom width' do
      result = described_class.render(headers: headers, rows: rows, width: 120)
      expect(result).to be_a(String)
    end

    it 'uses 80 as default width' do
      result_default = described_class.render(headers: headers, rows: rows)
      result_explicit = described_class.render(headers: headers, rows: rows, width: 80)
      expect(result_default).to eq(result_explicit)
    end

    it 'rescues errors and returns error message string' do
      allow(TTY::Table).to receive(:new).and_raise(StandardError, 'something went wrong')
      result = described_class.render(headers: headers, rows: rows)
      expect(result).to include('Table render error:')
      expect(result).to include('something went wrong')
    end

    it 'handles empty rows' do
      result = described_class.render(headers: headers, rows: [])
      expect(result).to be_a(String)
    end
  end
end
