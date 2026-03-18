# frozen_string_literal: true

require_relative 'lib/legion/tty/version'

Gem::Specification.new do |spec|
  spec.name          = 'legion-tty'
  spec.version       = Legion::TTY::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'Interactive terminal UI for the LegionIO framework'
  spec.description   = 'Rich TUI with onboarding wizard, AI chat shell, and operational dashboards for LegionIO'
  spec.homepage      = 'https://github.com/LegionIO/legion-tty'
  spec.license       = 'Apache-2.0'
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.4'
  spec.files = Dir['lib/**/*', 'exe/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  spec.bindir        = 'exe'
  spec.executables   = ['legion-tty']
  spec.extra_rdoc_files = %w[README.md LICENSE CHANGELOG.md]
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/LegionIO/legion-tty/issues',
    'changelog_uri' => 'https://github.com/LegionIO/legion-tty/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://github.com/LegionIO/legion-tty',
    'homepage_uri' => 'https://github.com/LegionIO/LegionIO',
    'source_code_uri' => 'https://github.com/LegionIO/legion-tty',
    'wiki_uri' => 'https://github.com/LegionIO/legion-tty/wiki',
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'pastel', '~> 0.8'
  spec.add_dependency 'tty-box', '~> 0.7'
  spec.add_dependency 'tty-cursor', '~> 0.7'
  spec.add_dependency 'tty-font', '~> 0.5'
  spec.add_dependency 'tty-markdown', '~> 0.7'
  spec.add_dependency 'tty-progressbar', '~> 0.18'
  spec.add_dependency 'tty-prompt', '~> 0.23'
  spec.add_dependency 'tty-reader', '~> 0.9'
  spec.add_dependency 'tty-screen', '~> 0.8'
  spec.add_dependency 'tty-spinner', '~> 0.9'
  spec.add_dependency 'tty-table', '~> 0.12'

  # spec.add_dependency 'legion-rbac', '~> 0.2'
  # spec.add_dependency 'lex-kerberos', '~> 0.1'
end
