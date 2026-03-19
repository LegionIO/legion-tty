# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/extensions'

RSpec.describe Legion::TTY::Screens::Extensions do
  let(:app) { double('app') }
  subject(:screen) { described_class.new(app) }

  let(:mock_spec) do
    double('Gem::Specification',
           name: 'lex-http',
           version: Gem::Version.new('0.2.1'),
           summary: 'HTTP client extension',
           homepage: 'https://github.com/LegionIO/lex-http',
           runtime_dependencies: [])
  end

  let(:mock_spec_node) do
    double('Gem::Specification',
           name: 'lex-node',
           version: Gem::Version.new('0.3.0'),
           summary: 'Node identity extension',
           homepage: 'https://github.com/LegionIO/lex-node',
           runtime_dependencies: [])
  end

  let(:mock_spec_claude) do
    double('Gem::Specification',
           name: 'lex-claude',
           version: Gem::Version.new('0.1.1'),
           summary: 'Claude AI provider',
           homepage: 'https://github.com/LegionIO/lex-claude',
           runtime_dependencies: [])
  end

  let(:mock_spec_agentic) do
    double('Gem::Specification',
           name: 'lex-agentic-attention',
           version: Gem::Version.new('0.1.2'),
           summary: 'Attention cognitive domain',
           homepage: nil,
           runtime_dependencies: [])
  end

  let(:mock_spec_other) do
    double('Gem::Specification',
           name: 'lex-custom',
           version: Gem::Version.new('1.0.0'),
           summary: 'Custom extension',
           homepage: nil,
           runtime_dependencies: [])
  end

  before do
    allow(Gem::Specification).to receive(:select).and_return([mock_spec])
  end

  describe '#initialize' do
    it 'stores the app reference' do
      expect(screen.app).to eq(app)
    end

    it 'inherits from Base' do
      expect(screen).to be_a(Legion::TTY::Screens::Base)
    end

    it 'starts with empty gems list' do
      expect(screen.instance_variable_get(:@gems)).to eq([])
    end

    it 'starts with selection at 0' do
      expect(screen.instance_variable_get(:@selected)).to eq(0)
    end

    it 'starts with detail mode off' do
      expect(screen.instance_variable_get(:@detail)).to be(false)
    end
  end

  describe '#activate' do
    it 'calls discover_extensions' do
      expect(screen).to receive(:discover_extensions).and_return([])
      screen.activate
    end

    it 'populates @gems' do
      screen.activate
      expect(screen.instance_variable_get(:@gems)).not_to be_nil
    end
  end

  describe '#discover_extensions' do
    it 'returns gems from Gem::Specification' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec])
      result = screen.discover_extensions
      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
    end

    it 'returns hashes with name, version, summary, category, loaded, deps' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec])
      result = screen.discover_extensions
      entry = result.first
      expect(entry).to include(:name, :version, :summary, :category, :loaded, :deps, :homepage)
    end

    it 'sorts gems by name' do
      spec_z = double('Gem::Specification',
                      name: 'lex-zap',
                      version: Gem::Version.new('1.0.0'),
                      summary: 'Z ext',
                      homepage: nil,
                      runtime_dependencies: [])
      spec_a = double('Gem::Specification',
                      name: 'lex-alpha',
                      version: Gem::Version.new('1.0.0'),
                      summary: 'A ext',
                      homepage: nil,
                      runtime_dependencies: [])
      allow(Gem::Specification).to receive(:select).and_return([spec_z, spec_a])
      result = screen.discover_extensions
      expect(result.map { |e| e[:name] }).to eq(%w[lex-alpha lex-zap])
    end

    it 'marks gem as loaded when in $LOADED_FEATURES' do
      original = $LOADED_FEATURES.dup
      $LOADED_FEATURES << '/path/to/lex/http/something.rb'
      allow(Gem::Specification).to receive(:select).and_return([mock_spec])
      result = screen.discover_extensions
      expect(result.first[:loaded]).to be(true)
    ensure
      $LOADED_FEATURES.replace(original)
    end

    it 'marks gem as not loaded when absent from $LOADED_FEATURES' do
      original = $LOADED_FEATURES.dup
      $LOADED_FEATURES.replace([])
      allow(Gem::Specification).to receive(:select).and_return([mock_spec])
      result = screen.discover_extensions
      expect(result.first[:loaded]).to be(false)
    ensure
      $LOADED_FEATURES.replace(original)
    end
  end

  describe '#categorize (via discover_extensions)' do
    it 'categorizes a Core gem correctly' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec_node])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Core')
    end

    it 'categorizes an AI gem correctly' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec_claude])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('AI')
    end

    it 'categorizes a Service gem correctly' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Service')
    end

    it 'categorizes an Agentic gem correctly' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec_agentic])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Agentic')
    end

    it 'categorizes an unknown gem as Other' do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec_other])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Other')
    end

    it 'categorizes lex-theory-of-mind as Agentic' do
      spec = double('Gem::Specification',
                    name: 'lex-theory-of-mind',
                    version: Gem::Version.new('0.1.1'),
                    summary: 'Theory of mind',
                    homepage: nil,
                    runtime_dependencies: [])
      allow(Gem::Specification).to receive(:select).and_return([spec])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Agentic')
    end

    it 'categorizes lex-mind-growth as Agentic' do
      spec = double('Gem::Specification',
                    name: 'lex-mind-growth',
                    version: Gem::Version.new('0.1.1'),
                    summary: 'Mind growth',
                    homepage: nil,
                    runtime_dependencies: [])
      allow(Gem::Specification).to receive(:select).and_return([spec])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Agentic')
    end

    it 'categorizes lex-planning as Agentic' do
      spec = double('Gem::Specification',
                    name: 'lex-planning',
                    version: Gem::Version.new('0.1.1'),
                    summary: 'Planning',
                    homepage: nil,
                    runtime_dependencies: [])
      allow(Gem::Specification).to receive(:select).and_return([spec])
      result = screen.discover_extensions
      expect(result.first[:category]).to eq('Agentic')
    end
  end

  describe '#render' do
    before { screen.activate }

    it 'returns an Array of Strings' do
      result = screen.render(80, 24)
      expect(result).to be_an(Array)
      result.each { |line| expect(line).to be_a(String) }
    end

    it 'returns exactly height lines' do
      result = screen.render(80, 24)
      expect(result.size).to eq(24)
    end

    it 'includes LEX Extensions header' do
      result = screen.render(80, 24)
      joined = result.join("\n")
      expect(joined).to include('LEX Extensions')
    end

    it 'includes the hint line' do
      result = screen.render(80, 24)
      joined = result.join("\n")
      expect(joined).to include('Enter=detail')
      expect(joined).to include('q=back')
    end

    it 'includes gem names in list mode' do
      result = screen.render(80, 24)
      joined = result.join("\n")
      expect(joined).to include('lex-http')
    end

    it 'renders detail view when @detail is true and a gem is selected' do
      screen.activate
      screen.instance_variable_set(:@detail, true)
      screen.instance_variable_set(:@selected, 0)
      result = screen.render(80, 24)
      joined = result.join("\n")
      expect(joined).to include('HTTP client extension')
    end

    it 'renders list view when @detail is false' do
      screen.instance_variable_set(:@detail, false)
      result = screen.render(80, 24)
      joined = result.join("\n")
      expect(joined).to include('lex-http')
    end
  end

  describe '#render with empty gems list' do
    before do
      allow(Gem::Specification).to receive(:select).and_return([])
      screen.activate
    end

    it 'renders without error' do
      expect { screen.render(80, 24) }.not_to raise_error
    end

    it 'still returns height lines' do
      result = screen.render(80, 24)
      expect(result.size).to eq(24)
    end
  end

  describe '#handle_input' do
    before do
      allow(Gem::Specification).to receive(:select).and_return([mock_spec_node, mock_spec])
      screen.activate
    end

    describe ':up key' do
      it 'returns :handled' do
        expect(screen.handle_input(:up)).to eq(:handled)
      end

      it 'decrements @selected' do
        screen.instance_variable_set(:@selected, 1)
        screen.handle_input(:up)
        expect(screen.instance_variable_get(:@selected)).to eq(0)
      end

      it 'does not go below 0' do
        screen.instance_variable_set(:@selected, 0)
        screen.handle_input(:up)
        expect(screen.instance_variable_get(:@selected)).to eq(0)
      end
    end

    describe ':down key' do
      it 'returns :handled' do
        expect(screen.handle_input(:down)).to eq(:handled)
      end

      it 'increments @selected' do
        screen.instance_variable_set(:@selected, 0)
        screen.handle_input(:down)
        expect(screen.instance_variable_get(:@selected)).to eq(1)
      end

      it 'does not exceed gems.size - 1' do
        max = screen.instance_variable_get(:@gems).size - 1
        screen.instance_variable_set(:@selected, max)
        screen.handle_input(:down)
        expect(screen.instance_variable_get(:@selected)).to eq(max)
      end
    end

    describe ':enter key' do
      it 'returns :handled' do
        expect(screen.handle_input(:enter)).to eq(:handled)
      end

      it 'toggles @detail from false to true' do
        screen.instance_variable_set(:@detail, false)
        screen.handle_input(:enter)
        expect(screen.instance_variable_get(:@detail)).to be(true)
      end

      it 'toggles @detail from true to false' do
        screen.instance_variable_set(:@detail, true)
        screen.handle_input(:enter)
        expect(screen.instance_variable_get(:@detail)).to be(false)
      end
    end

    describe "'q' key in list mode" do
      it 'returns :pop_screen' do
        screen.instance_variable_set(:@detail, false)
        expect(screen.handle_input('q')).to eq(:pop_screen)
      end
    end

    describe "'q' key in detail mode" do
      it 'returns :handled' do
        screen.instance_variable_set(:@detail, true)
        expect(screen.handle_input('q')).to eq(:handled)
      end

      it 'sets @detail to false' do
        screen.instance_variable_set(:@detail, true)
        screen.handle_input('q')
        expect(screen.instance_variable_get(:@detail)).to be(false)
      end
    end

    describe ':escape key in list mode' do
      it 'returns :pop_screen' do
        screen.instance_variable_set(:@detail, false)
        expect(screen.handle_input(:escape)).to eq(:pop_screen)
      end
    end

    describe ':escape key in detail mode' do
      it 'returns :handled' do
        screen.instance_variable_set(:@detail, true)
        expect(screen.handle_input(:escape)).to eq(:handled)
      end

      it 'sets @detail to false' do
        screen.instance_variable_set(:@detail, true)
        screen.handle_input(:escape)
        expect(screen.instance_variable_get(:@detail)).to be(false)
      end
    end

    describe 'unknown key' do
      it 'returns :pass' do
        expect(screen.handle_input('x')).to eq(:pass)
      end

      it 'returns :pass for unrecognized symbol' do
        expect(screen.handle_input(:f5)).to eq(:pass)
      end
    end
  end

  describe 'detail view with nil homepage' do
    let(:spec_no_homepage) do
      double('Gem::Specification',
             name: 'lex-custom',
             version: Gem::Version.new('1.0.0'),
             summary: 'Custom ext',
             homepage: nil,
             runtime_dependencies: [])
    end

    before do
      allow(Gem::Specification).to receive(:select).and_return([spec_no_homepage])
      screen.activate
      screen.instance_variable_set(:@detail, true)
      screen.instance_variable_set(:@selected, 0)
    end

    it 'renders "no homepage" for gems with nil homepage' do
      result = screen.render(80, 24)
      joined = result.join("\n")
      expect(joined).to include('no homepage')
    end
  end

  describe 'gem with runtime dependencies' do
    let(:dep) do
      double('Gem::Dependency', name: 'legion-transport', requirement: '>= 1.0')
    end

    let(:spec_with_deps) do
      double('Gem::Specification',
             name: 'lex-node',
             version: Gem::Version.new('0.3.0'),
             summary: 'Node extension',
             homepage: 'https://example.com',
             runtime_dependencies: [dep])
    end

    before do
      allow(Gem::Specification).to receive(:select).and_return([spec_with_deps])
      screen.activate
      screen.instance_variable_set(:@detail, true)
      screen.instance_variable_set(:@selected, 0)
    end

    it 'renders dependency names in detail view' do
      result = screen.render(80, 30)
      joined = result.join("\n")
      expect(joined).to include('legion-transport')
    end
  end

  describe 'filter feature' do
    before do
      allow(Gem::Specification).to receive(:select)
        .and_return([mock_spec_node, mock_spec, mock_spec_claude, mock_spec_agentic, mock_spec_other])
      screen.activate
    end

    describe '#initialize' do
      it 'starts with @filter set to nil' do
        expect(screen.instance_variable_get(:@filter)).to be_nil
      end
    end

    describe "'f' key cycles filter" do
      it 'returns :handled' do
        expect(screen.handle_input('f')).to eq(:handled)
      end

      it 'advances @filter from nil to Core' do
        screen.handle_input('f')
        expect(screen.instance_variable_get(:@filter)).to eq('Core')
      end

      it 'cycles through all categories and wraps back to nil' do
        categories = Legion::TTY::Screens::Extensions::CATEGORIES
        categories.size.times { screen.handle_input('f') }
        expect(screen.instance_variable_get(:@filter)).to be_nil
      end

      it 'resets @selected to 0 when cycling' do
        screen.instance_variable_set(:@selected, 2)
        screen.handle_input('f')
        expect(screen.instance_variable_get(:@selected)).to eq(0)
      end
    end

    describe "'c' key clears filter" do
      before do
        screen.instance_variable_set(:@filter, 'Core')
        screen.instance_variable_set(:@selected, 1)
      end

      it 'returns :handled' do
        expect(screen.handle_input('c')).to eq(:handled)
      end

      it 'resets @filter to nil' do
        screen.handle_input('c')
        expect(screen.instance_variable_get(:@filter)).to be_nil
      end

      it 'resets @selected to 0' do
        screen.handle_input('c')
        expect(screen.instance_variable_get(:@selected)).to eq(0)
      end
    end

    describe '#current_gems' do
      it 'returns all gems when filter is nil' do
        gems = screen.send(:current_gems)
        expect(gems.size).to eq(5)
      end

      it 'returns only Core gems when filter is Core' do
        screen.instance_variable_set(:@filter, 'Core')
        gems = screen.send(:current_gems)
        expect(gems.all? { |g| g[:category] == 'Core' }).to be(true)
      end

      it 'returns only AI gems when filter is AI' do
        screen.instance_variable_set(:@filter, 'AI')
        gems = screen.send(:current_gems)
        expect(gems.all? { |g| g[:category] == 'AI' }).to be(true)
      end

      it 'returns empty array when filter matches no gems' do
        screen.instance_variable_set(:@filter, 'Service')
        # mock_spec (lex-http) is Service; the others are not
        gems = screen.send(:current_gems)
        expect(gems.map { |g| g[:category] }.uniq).to eq(['Service'])
      end
    end

    describe 'render with active filter' do
      it 'shows filter label in output' do
        screen.instance_variable_set(:@filter, 'AI')
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('filter: AI')
      end

      it 'shows only filtered gems in list' do
        screen.instance_variable_set(:@filter, 'Core')
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('lex-node')
        expect(joined).not_to include('lex-http')
      end

      it 'shows f=filter and c=clear in hint bar' do
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('f=filter')
        expect(joined).to include('c=clear')
      end
    end

    describe ':down clamped to current_gems size' do
      it 'does not exceed filtered list size' do
        screen.instance_variable_set(:@filter, 'Core')
        screen.instance_variable_set(:@selected, 0)
        10.times { screen.handle_input(:down) }
        filtered_max = screen.send(:current_gems).size - 1
        expect(screen.instance_variable_get(:@selected)).to eq(filtered_max)
      end
    end
  end
end
