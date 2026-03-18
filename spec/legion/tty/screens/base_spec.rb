# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/base'

RSpec.describe Legion::TTY::Screens::Base do
  let(:app) { double('app') }
  subject(:screen) { described_class.new(app) }

  describe '#initialize' do
    it 'stores the app reference' do
      expect(screen.app).to eq(app)
    end
  end

  describe 'lifecycle methods' do
    it 'responds to activate' do
      expect(screen).to respond_to(:activate)
    end

    it 'responds to deactivate' do
      expect(screen).to respond_to(:deactivate)
    end

    it 'responds to teardown' do
      expect(screen).to respond_to(:teardown)
    end

    it 'activate is a no-op (returns nil)' do
      expect(screen.activate).to be_nil
    end

    it 'deactivate is a no-op (returns nil)' do
      expect(screen.deactivate).to be_nil
    end

    it 'teardown is a no-op (returns nil)' do
      expect(screen.teardown).to be_nil
    end
  end

  describe '#render' do
    it 'raises NotImplementedError' do
      expect { screen.render(80, 24) }.to raise_error(NotImplementedError)
    end

    it 'includes the class name in the error message' do
      expect { screen.render(80, 24) }.to raise_error(NotImplementedError, /#{described_class}/)
    end
  end

  describe '#handle_input' do
    it 'returns :pass by default' do
      expect(screen.handle_input(:up)).to eq(:pass)
    end

    it 'returns :pass for any key' do
      expect(screen.handle_input(:enter)).to eq(:pass)
      expect(screen.handle_input('q')).to eq(:pass)
    end
  end
end
