# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::TTY::Screens::Onboarding do
  let(:app) { double('app') }
  let(:wizard) { instance_double(Legion::TTY::Components::WizardPrompt) }
  let(:output) { StringIO.new }
  let(:onboarding) { described_class.new(app, wizard: wizard, output: output, skip_rain: true) }

  before do
    allow(wizard).to receive(:confirm).and_return(false)
    allow(wizard).to receive(:ask_name).and_return('Test')
    allow(wizard).to receive(:ask_name_with_default).and_return('Test')
    allow(wizard).to receive(:display_provider_results)
    allow(wizard).to receive(:select_default_provider)
  end

  describe '#run_service_auth' do
    context 'when Teams is detected and gem is loadable' do
      before do
        allow(onboarding).to receive(:teams_detected?).and_return(true)
        allow(onboarding).to receive(:teams_gem_loadable?).and_return(true)
        allow(onboarding).to receive(:teams_already_authenticated?).and_return(false)
      end

      it 'prompts the user to connect' do
        expect(wizard).to receive(:confirm).with(/Microsoft Teams/).and_return(false)
        onboarding.send(:run_service_auth)
      end

      it 'runs BrowserAuth when user agrees' do
        allow(wizard).to receive(:confirm).with(/Microsoft Teams/).and_return(true)
        browser_auth = double('browser_auth', authenticate: { access_token: 'tok' })
        allow(onboarding).to receive(:build_teams_browser_auth).and_return(browser_auth)
        allow(onboarding).to receive(:store_teams_token)
        expect(browser_auth).to receive(:authenticate)
        onboarding.send(:run_service_auth)
      end

      it 'skips when already authenticated' do
        allow(onboarding).to receive(:teams_already_authenticated?).and_return(true)
        expect(wizard).not_to receive(:confirm).with(/Microsoft Teams/)
        onboarding.send(:run_service_auth)
      end
    end

    context 'when Teams is not detected' do
      before do
        allow(onboarding).to receive(:teams_detected?).and_return(false)
      end

      it 'does not prompt' do
        expect(wizard).not_to receive(:confirm).with(/Microsoft Teams/)
        onboarding.send(:run_service_auth)
      end
    end
  end

  describe '#teams_gem_loadable?' do
    it 'returns true when gem spec exists' do
      allow(Gem::Specification).to receive(:find_by_name).with('lex-microsoft_teams').and_return(double)
      expect(onboarding.send(:teams_gem_loadable?)).to be true
    end

    it 'returns false when gem is missing' do
      allow(Gem::Specification).to receive(:find_by_name)
        .with('lex-microsoft_teams')
        .and_raise(Gem::MissingSpecError.new('lex-microsoft_teams', nil))
      expect(onboarding.send(:teams_gem_loadable?)).to be false
    end
  end

  describe '#teams_already_authenticated?' do
    it 'checks for token file existence' do
      allow(File).to receive(:exist?).and_call_original
      token_path = File.expand_path('~/.legionio/tokens/microsoft_teams.json')
      allow(File).to receive(:exist?).with(token_path).and_return(false)
      expect(onboarding.send(:teams_already_authenticated?)).to be false
    end
  end
end
