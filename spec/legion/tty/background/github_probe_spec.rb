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
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('env-token')
      instance = described_class.new
      expect(instance).to be_a(described_class)
    end
  end

  describe 'infer_username (private)' do
    it 'extracts username from HTTPS URL' do
      url = 'https://github.com/LegionIO/legion-tty'
      expect(probe.send(:infer_username, url)).to eq('LegionIO')
    end

    it 'extracts username from SSH URL' do
      url = 'git@github.com:LegionIO/legion-tty.git'
      expect(probe.send(:infer_username, url)).to eq('LegionIO')
    end

    it 'extracts username from HTTPS URL with .git suffix' do
      url = 'https://github.com/octocat/hello-world.git'
      expect(probe.send(:infer_username, url)).to eq('octocat')
    end

    it 'returns nil for non-GitHub URLs' do
      url = 'https://gitlab.com/someuser/repo.git'
      expect(probe.send(:infer_username, url)).to be_nil
    end

    it 'returns nil for nil input' do
      expect(probe.send(:infer_username, nil)).to be_nil
    end

    it 'returns nil for empty string' do
      expect(probe.send(:infer_username, '')).to be_nil
    end
  end

  describe 'extract_profile (private)' do
    it 'extracts profile fields from API response' do
      data = {
        'login' => 'octocat',
        'name' => 'The Octocat',
        'bio' => 'A cat',
        'public_repos' => 10,
        'total_private_repos' => 5,
        'company' => 'GitHub',
        'location' => 'San Francisco',
        'email' => 'octocat@github.com',
        'created_at' => '2011-01-25T00:00:00Z',
        'followers' => 100,
        'following' => 50
      }
      result = probe.send(:extract_profile, data)
      expect(result[:login]).to eq('octocat')
      expect(result[:name]).to eq('The Octocat')
      expect(result[:public_repos]).to eq(10)
    end
  end

  describe 'extract_repo (private)' do
    it 'extracts repo fields from API response' do
      data = {
        'full_name' => 'octocat/hello',
        'language' => 'Ruby',
        'private' => false,
        'updated_at' => '2024-01-01',
        'description' => 'A test repo'
      }
      result = probe.send(:extract_repo, data)
      expect(result[:full_name]).to eq('octocat/hello')
      expect(result[:language]).to eq('Ruby')
    end
  end

  describe '#run_quick_async' do
    it 'returns a Thread' do
      queue = Queue.new
      allow(probe).to receive(:fetch_quick_profile).and_return(nil)
      thread = probe.run_quick_async(queue)
      expect(thread).to be_a(Thread)
      thread.join(5)
    end

    it 'pushes a github_quick_complete event' do
      queue = Queue.new
      allow(probe).to receive(:fetch_quick_profile).and_return(nil)
      thread = probe.run_quick_async(queue)
      thread.join(5)
      event = queue.pop(true)
      expect(event[:type]).to eq(:github_quick_complete)
    end
  end

  describe '#run_async' do
    it 'returns a Thread' do
      queue = Queue.new
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
