# frozen_string_literal: true

RSpec.describe Legion::TTY do
  it 'has a version number' do
    expect(Legion::TTY::VERSION).not_to be_nil
  end

  it 'version is semver format' do
    expect(Legion::TTY::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
