# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/background/github_probe'

RSpec.describe Legion::TTY::Background::GitHubProbe do
  subject(:probe) { described_class.new(token: 'test-token') }

  describe '#initialize' do
    it 'accepts a token argument' do
      expect(probe).to be_a(described_class)
    end

    it 'falls back to ENV GITHUB_TOKEN when no token given' do
      allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('env-token')
      instance = described_class.new
      expect(instance).to be_a(described_class)
    end
  end

  describe '#infer_username' do
    it 'extracts username from HTTPS URL' do
      url = 'https://github.com/LegionIO/legion-tty'
      expect(probe.infer_username(url)).to eq('LegionIO')
    end

    it 'extracts username from SSH URL' do
      url = 'git@github.com:LegionIO/legion-tty.git'
      expect(probe.infer_username(url)).to eq('LegionIO')
    end

    it 'extracts username from HTTPS URL with .git suffix' do
      url = 'https://github.com/octocat/hello-world.git'
      expect(probe.infer_username(url)).to eq('octocat')
    end

    it 'returns nil for non-GitHub URLs' do
      url = 'https://gitlab.com/someuser/repo.git'
      expect(probe.infer_username(url)).to be_nil
    end

    it 'returns nil for nil input' do
      expect(probe.infer_username(nil)).to be_nil
    end

    it 'returns nil for empty string' do
      expect(probe.infer_username('')).to be_nil
    end
  end

  describe '#fetch_profile' do
    it 'responds to fetch_profile' do
      expect(probe).to respond_to(:fetch_profile)
    end
  end

  describe '#fetch_recent_events' do
    it 'responds to fetch_recent_events' do
      expect(probe).to respond_to(:fetch_recent_events)
    end
  end

  describe '#fetch_recent_repos' do
    it 'responds to fetch_recent_repos' do
      expect(probe).to respond_to(:fetch_recent_repos)
    end
  end

  describe '#run_async' do
    it 'returns a Thread' do
      queue = Queue.new
      # Stub api_get to avoid real network calls
      allow(probe).to receive(:api_get).and_return(nil)
      thread = probe.run_async(queue, remotes: [])
      expect(thread).to be_a(Thread)
      thread.join(5)
    end

    it 'pushes an event to the queue' do
      queue = Queue.new
      allow(probe).to receive(:api_get).and_return(nil)
      thread = probe.run_async(queue, remotes: [])
      thread.join(5)
      expect(queue.empty?).to be(false)
    end
  end
end
