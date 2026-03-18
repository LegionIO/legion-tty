# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe 'Legion::TTY integration' do
  it 'loads all core modules' do
    expect(defined?(Legion::TTY::App)).to be_truthy
    expect(defined?(Legion::TTY::ScreenManager)).to be_truthy
    expect(defined?(Legion::TTY::Theme)).to be_truthy
    expect(defined?(Legion::TTY::Hotkeys)).to be_truthy
  end

  it 'loads all screens' do
    expect(defined?(Legion::TTY::Screens::Base)).to be_truthy
    expect(defined?(Legion::TTY::Screens::Chat)).to be_truthy
    expect(defined?(Legion::TTY::Screens::Onboarding)).to be_truthy
    expect(defined?(Legion::TTY::Screens::Dashboard)).to be_truthy
  end

  it 'loads all components' do
    expect(defined?(Legion::TTY::Components::DigitalRain)).to be_truthy
    expect(defined?(Legion::TTY::Components::InputBar)).to be_truthy
    expect(defined?(Legion::TTY::Components::MessageStream)).to be_truthy
    expect(defined?(Legion::TTY::Components::StatusBar)).to be_truthy
    expect(defined?(Legion::TTY::Components::ToolPanel)).to be_truthy
    expect(defined?(Legion::TTY::Components::MarkdownView)).to be_truthy
    expect(defined?(Legion::TTY::Components::WizardPrompt)).to be_truthy
    expect(defined?(Legion::TTY::Components::TokenTracker)).to be_truthy
  end

  it 'loads background modules' do
    expect(defined?(Legion::TTY::Background::Scanner)).to be_truthy
    expect(defined?(Legion::TTY::Background::GitHubProbe)).to be_truthy
    expect(defined?(Legion::TTY::Background::KerberosProbe)).to be_truthy
  end

  it 'loads session store' do
    expect(defined?(Legion::TTY::SessionStore)).to be_truthy
  end

  it 'can instantiate App' do
    Dir.mktmpdir do |dir|
      app = Legion::TTY::App.new(config_dir: dir)
      expect(app).to be_a(Legion::TTY::App)
      expect(app.screen_manager).to be_a(Legion::TTY::ScreenManager)
      expect(app.hotkeys).to be_a(Legion::TTY::Hotkeys)
    end
  end
end
