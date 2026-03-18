# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/dashboard'

RSpec.describe Legion::TTY::Screens::Dashboard do
  let(:app) { double('app') }
  subject(:dashboard) { described_class.new(app) }

  describe '#initialize' do
    it 'stores the app reference' do
      expect(dashboard.app).to eq(app)
    end

    it 'inherits from Base' do
      expect(dashboard).to be_a(Legion::TTY::Screens::Base)
    end
  end

  describe '#activate' do
    it 'refreshes data' do
      dashboard.activate
      # After activate, render should work without error
      expect { dashboard.render(80, 24) }.not_to raise_error
    end
  end

  describe '#render' do
    before { dashboard.activate }

    it 'returns an array of strings' do
      result = dashboard.render(80, 24)
      expect(result).to be_an(Array)
      result.each { |line| expect(line).to be_a(String) }
    end

    it 'returns exactly height lines' do
      result = dashboard.render(80, 24)
      expect(result.size).to eq(24)
    end

    it 'includes Services section' do
      result = dashboard.render(80, 30)
      joined = result.join("\n")
      expect(joined).to include('Services')
    end

    it 'includes Extensions section' do
      result = dashboard.render(80, 30)
      joined = result.join("\n")
      expect(joined).to include('Extensions')
    end

    it 'includes System section' do
      result = dashboard.render(80, 30)
      joined = result.join("\n")
      expect(joined).to include('System')
    end

    it 'includes Ruby version' do
      result = dashboard.render(80, 30)
      joined = result.join("\n")
      expect(joined).to include(RUBY_VERSION)
    end

    it 'includes Recent Activity section' do
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include('Recent Activity')
    end
  end

  describe '#handle_input' do
    it 'returns :handled for r key (refresh)' do
      dashboard.activate
      expect(dashboard.handle_input('r')).to eq(:handled)
    end

    it 'returns :pop_screen for q key' do
      expect(dashboard.handle_input('q')).to eq(:pop_screen)
    end

    it 'returns :pop_screen for escape' do
      expect(dashboard.handle_input(:escape)).to eq(:pop_screen)
    end

    it 'returns :pass for unknown keys' do
      expect(dashboard.handle_input('x')).to eq(:pass)
    end

    it 'returns :handled for f5 key' do
      dashboard.activate
      expect(dashboard.handle_input(:f5)).to eq(:handled)
    end
  end

  describe '#refresh_data' do
    it 'updates cached data' do
      dashboard.refresh_data
      result = dashboard.render(80, 24)
      expect(result).not_to be_empty
    end

    it 'can be called multiple times' do
      3.times { dashboard.refresh_data }
      expect { dashboard.render(80, 24) }.not_to raise_error
    end
  end
end
