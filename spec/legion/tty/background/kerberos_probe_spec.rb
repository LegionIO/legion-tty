# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/background/kerberos_probe'

RSpec.describe Legion::TTY::Background::KerberosProbe do
  subject(:probe) { described_class.new }

  describe '#initialize' do
    it 'creates a probe instance' do
      expect(probe).to be_a(described_class)
    end

    it 'accepts a logger' do
      logger = double('logger', log: nil)
      instance = described_class.new(logger: logger)
      expect(instance).to be_a(described_class)
    end
  end

  describe '#probe' do
    context 'when klist returns a principal' do
      before do
        allow(probe).to receive(:read_principal).and_return('jdoe@EXAMPLE.COM')
        allow(probe).to receive(:ldap_profile).and_return({
                                                            first_name: 'Jane',
                                                            last_name: 'Doe',
                                                            display_name: 'Jane Doe',
                                                            email: 'jdoe@example.com',
                                                            title: 'Senior Engineer',
                                                            department: 'Engineering',
                                                            company: 'Acme Corp'
                                                          })
      end

      it 'returns a hash with principal' do
        result = probe.probe
        expect(result).to be_a(Hash)
        expect(result[:principal]).to eq('jdoe@EXAMPLE.COM')
      end

      it 'extracts username from principal' do
        result = probe.probe
        expect(result[:username]).to eq('jdoe')
      end

      it 'extracts realm from principal' do
        result = probe.probe
        expect(result[:realm]).to eq('EXAMPLE.COM')
      end

      it 'includes LDAP profile fields' do
        result = probe.probe
        expect(result[:first_name]).to eq('Jane')
        expect(result[:title]).to eq('Senior Engineer')
      end
    end

    context 'when klist returns no principal' do
      before do
        allow(probe).to receive(:read_principal).and_return(nil)
      end

      it 'returns nil' do
        result = probe.probe
        expect(result).to be_nil
      end
    end
  end

  describe '#run_async' do
    it 'returns a Thread' do
      queue = Queue.new
      allow(probe).to receive(:probe).and_return(nil)
      thread = probe.run_async(queue)
      expect(thread).to be_a(Thread)
      thread.join(5)
    end

    it 'pushes a kerberos_complete event' do
      queue = Queue.new
      allow(probe).to receive(:probe).and_return(nil)
      thread = probe.run_async(queue)
      thread.join(5)
      event = queue.pop(true)
      expect(event[:type]).to eq(:kerberos_complete)
    end

    it 'pushes identity data when available' do
      queue = Queue.new
      identity = { principal: 'jdoe@EXAMPLE.COM', username: 'jdoe' }
      allow(probe).to receive(:probe).and_return(identity)
      thread = probe.run_async(queue)
      thread.join(5)
      event = queue.pop(true)
      expect(event[:data]).to eq(identity)
    end
  end

  describe 'private methods' do
    describe 'realm_to_base_dn' do
      it 'converts realm to LDAP base DN' do
        result = probe.send(:realm_to_base_dn, 'EXAMPLE.COM')
        expect(result).to eq('DC=example,DC=com')
      end

      it 'handles multi-level domains' do
        result = probe.send(:realm_to_base_dn, 'SUB.EXAMPLE.COM')
        expect(result).to eq('DC=sub,DC=example,DC=com')
      end
    end

    describe 'parse_ldif' do
      let(:ldif_output) do
        <<~LDIF
          givenName: Jane
          sn: Doe
          mail: jdoe@example.com
          displayName: Jane Doe
          title: Senior Engineer
          department: Engineering
          company: Acme Corp
          l: Minneapolis
          st: Minnesota
          co: United States
          whenCreated: 20200115093045.0Z
        LDIF
      end

      it 'parses givenName' do
        result = probe.send(:parse_ldif, ldif_output)
        expect(result[:first_name]).to eq('Jane')
      end

      it 'parses sn as last_name' do
        result = probe.send(:parse_ldif, ldif_output)
        expect(result[:last_name]).to eq('Doe')
      end

      it 'parses mail as email' do
        result = probe.send(:parse_ldif, ldif_output)
        expect(result[:email]).to eq('jdoe@example.com')
      end

      it 'parses title' do
        result = probe.send(:parse_ldif, ldif_output)
        expect(result[:title]).to eq('Senior Engineer')
      end

      it 'parses city from l attribute' do
        result = probe.send(:parse_ldif, ldif_output)
        expect(result[:city]).to eq('Minneapolis')
      end

      it 'parses state from st attribute' do
        result = probe.send(:parse_ldif, ldif_output)
        expect(result[:state]).to eq('Minnesota')
      end
    end

    describe 'calculate_tenure' do
      it 'returns nil for nil input' do
        result = probe.send(:calculate_tenure, nil)
        expect(result).to be_nil
      end

      it 'returns nil for short string' do
        result = probe.send(:calculate_tenure, '2020')
        expect(result).to be_nil
      end

      it 'returns a hash with years, months, days for valid input' do
        result = probe.send(:calculate_tenure, '20200115093045.0Z')
        expect(result).to be_a(Hash)
        expect(result).to include(:years, :months, :days)
        expect(result[:years]).to be >= 5
      end

      it 'returns nil for zero year' do
        result = probe.send(:calculate_tenure, '00000101000000.0Z')
        expect(result).to be_nil
      end
    end

    describe 'build_result' do
      it 'builds complete result hash' do
        result = probe.send(:build_result,
                            principal: 'jdoe@EXAMPLE.COM',
                            username: 'jdoe',
                            realm: 'EXAMPLE.COM',
                            profile: { first_name: 'Jane', last_name: 'Doe' })
        expect(result[:principal]).to eq('jdoe@EXAMPLE.COM')
        expect(result[:first_name]).to eq('Jane')
        expect(result[:display_name]).to eq('Jane Doe')
      end

      it 'falls back to capitalized username when no first_name' do
        result = probe.send(:build_result,
                            principal: 'jdoe@EXAMPLE.COM',
                            username: 'jdoe',
                            realm: 'EXAMPLE.COM',
                            profile: {})
        expect(result[:first_name]).to eq('Jdoe')
      end
    end
  end
end
