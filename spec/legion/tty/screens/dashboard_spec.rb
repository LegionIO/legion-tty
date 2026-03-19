# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/dashboard'

RSpec.describe Legion::TTY::Screens::Dashboard do
  let(:app) { double('app') }
  subject(:dashboard) { described_class.new(app) }

  before do
    allow(dashboard).to receive(:port_open?).and_return(false)
    allow(dashboard).to receive(:format_memory).and_return('10.0 MB')
  end

  describe 'PANELS constant' do
    it 'contains 5 panel symbols' do
      expect(described_class::PANELS.size).to eq(5)
    end

    it 'includes :services, :llm, :extensions, :system, :activity' do
      expect(described_class::PANELS).to eq(%i[services llm extensions system activity])
    end
  end

  describe '#initialize' do
    it 'stores the app reference' do
      expect(dashboard.app).to eq(app)
    end

    it 'inherits from Base' do
      expect(dashboard).to be_a(Legion::TTY::Screens::Base)
    end

    it 'initializes @selected_panel to 0' do
      expect(dashboard.instance_variable_get(:@selected_panel)).to eq(0)
    end
  end

  describe '#selected_panel' do
    it 'returns the panel symbol for the current index' do
      dashboard.instance_variable_set(:@selected_panel, 0)
      expect(dashboard.selected_panel).to eq(:services)
    end

    it 'returns :llm when index is 1' do
      dashboard.instance_variable_set(:@selected_panel, 1)
      expect(dashboard.selected_panel).to eq(:llm)
    end
  end

  describe '#llm_info (private)' do
    it 'returns a hash with provider, started, daemon keys' do
      info = dashboard.send(:llm_info)
      expect(info).to have_key(:provider)
      expect(info).to have_key(:started)
      expect(info).to have_key(:daemon)
    end

    it 'returns provider none when Legion::LLM is not defined' do
      info = dashboard.send(:llm_info)
      expect(info[:provider]).to eq('none')
    end

    it 'returns started false when Legion::LLM is not defined' do
      info = dashboard.send(:llm_info)
      expect(info[:started]).to be false
    end

    it 'returns daemon false when Legion::LLM::DaemonClient is not defined' do
      info = dashboard.send(:llm_info)
      expect(info[:daemon]).to be false
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
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include('Services')
    end

    it 'includes LLM section' do
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include('LLM')
    end

    it 'includes Extensions section' do
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include('Extensions')
    end

    it 'includes System section' do
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include('System')
    end

    it 'includes Ruby version' do
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include(RUBY_VERSION)
    end

    it 'includes Recent Activity section' do
      result = dashboard.render(80, 50)
      joined = result.join("\n")
      expect(joined).to include('Recent Activity')
    end

    it 'shows >> prefix on selected panel' do
      dashboard.instance_variable_set(:@selected_panel, 0)
      result = dashboard.render(80, 40)
      joined = result.join("\n")
      expect(joined).to include('>>')
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

    it 'returns :handled for j key (navigate down)' do
      expect(dashboard.handle_input('j')).to eq(:handled)
    end

    it 'returns :handled for k key (navigate up)' do
      expect(dashboard.handle_input('k')).to eq(:handled)
    end

    it 'returns :handled for down arrow (navigate down)' do
      expect(dashboard.handle_input(:down)).to eq(:handled)
    end

    it 'returns :handled for up arrow (navigate up)' do
      expect(dashboard.handle_input(:up)).to eq(:handled)
    end

    it 'returns :handled for number key 1' do
      expect(dashboard.handle_input('1')).to eq(:handled)
    end

    it 'returns :handled for number key 2' do
      expect(dashboard.handle_input('2')).to eq(:handled)
    end

    it 'returns :handled for number key 3' do
      expect(dashboard.handle_input('3')).to eq(:handled)
    end

    it 'returns :handled for number key 4' do
      expect(dashboard.handle_input('4')).to eq(:handled)
    end

    it 'returns :handled for number key 5' do
      expect(dashboard.handle_input('5')).to eq(:handled)
    end

    it 'navigates panels in a cycle with j' do
      initial = dashboard.instance_variable_get(:@selected_panel)
      dashboard.handle_input('j')
      expect(dashboard.instance_variable_get(:@selected_panel)).to eq((initial + 1) % Legion::TTY::Screens::Dashboard::PANELS.size)
    end

    it 'navigates panels in a cycle with k' do
      dashboard.instance_variable_set(:@selected_panel, 0)
      dashboard.handle_input('k')
      expect(dashboard.instance_variable_get(:@selected_panel)).to eq(Legion::TTY::Screens::Dashboard::PANELS.size - 1)
    end

    it 'jumps to panel 1 with key 1' do
      dashboard.instance_variable_set(:@selected_panel, 3)
      dashboard.handle_input('1')
      expect(dashboard.instance_variable_get(:@selected_panel)).to eq(0)
    end

    it 'jumps to panel 5 with key 5' do
      dashboard.instance_variable_set(:@selected_panel, 0)
      dashboard.handle_input('5')
      expect(dashboard.instance_variable_get(:@selected_panel)).to eq(4)
    end

    it 'returns :pass for e key when not on extensions panel' do
      dashboard.instance_variable_set(:@selected_panel, 0)
      allow(app).to receive(:respond_to?).and_return(false)
      expect(dashboard.handle_input('e')).to eq(:pass)
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
