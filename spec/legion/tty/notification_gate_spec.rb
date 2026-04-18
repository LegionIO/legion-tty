# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/notification_gate'

RSpec.describe Legion::TTY::NotificationGate do
  describe '.should_deliver?' do
    context 'when Legion::Gaia::NotificationGate is not defined' do
      it 'returns true' do
        expect(described_class.should_deliver?(priority: :normal)).to be true
      end

      it 'returns true for ambient priority' do
        expect(described_class.should_deliver?(priority: :ambient)).to be true
      end
    end

    context 'when Legion::Gaia::NotificationGate is available' do
      let(:gate_instance) { double('gate_instance') }

      before do
        gate = gate_instance
        gate_mod = Module.new
        gate_mod.define_singleton_method(:instance) { gate }
        stub_const('Legion::Gaia::NotificationGate', gate_mod)
      end

      it 'returns true when gate.should_notify? returns true' do
        allow(gate_instance).to receive(:should_notify?).with(priority: :normal).and_return(true)
        expect(described_class.should_deliver?(priority: :normal)).to be true
      end

      it 'returns false when gate.should_notify? returns false' do
        allow(gate_instance).to receive(:should_notify?).with(priority: :normal).and_return(false)
        expect(described_class.should_deliver?(priority: :normal)).to be false
      end

      it 'returns true on StandardError (rescue path)' do
        allow(gate_instance).to receive(:should_notify?).and_raise(StandardError, 'boom')
        expect(described_class.should_deliver?(priority: :normal)).to be true
      end
    end
  end

  describe '.update_presence' do
    context 'when Legion::Gaia::NotificationGate is not defined' do
      it 'no-ops and returns nil' do
        expect { described_class.update_presence(availability: 'Available') }.not_to raise_error
        expect(described_class.update_presence(availability: 'Available')).to be_nil
      end
    end

    context 'when Legion::Gaia::NotificationGate is available' do
      let(:gate_instance) { double('gate_instance') }

      before do
        gate = gate_instance
        gate_mod = Module.new
        gate_mod.define_singleton_method(:instance) { gate }
        stub_const('Legion::Gaia::NotificationGate', gate_mod)
      end

      it 'delegates to gate.instance.update_presence' do
        allow(gate_instance).to receive(:update_presence)
        described_class.update_presence(availability: 'Busy')
        expect(gate_instance).to have_received(:update_presence).with(availability: 'Busy', activity: nil)
      end

      it 'passes activity when provided' do
        allow(gate_instance).to receive(:update_presence)
        described_class.update_presence(availability: 'Away', activity: 'coding')
        expect(gate_instance).to have_received(:update_presence).with(availability: 'Away', activity: 'coding')
      end
    end
  end
end
