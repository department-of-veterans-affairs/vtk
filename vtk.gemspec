# frozen_string_literal: true

require_relative 'lib/vtk/version'

Gem::Specification.new do |spec|
  spec.name          = 'vtk'
  spec.license       = 'MIT'
  spec.version       = Vtk::VERSION
  spec.authors       = ['Eric Boehs', 'Lindsey Hattamer', 'Travis Hilton']
  spec.email         = ['eric.boehs@oddball.io', 'lindsey.hattamer@oddball.io', 'travis.hilton@oddball.io']

  spec.summary       = 'A CLI for the platform'
  spec.description   = 'This is a platform CLI tool for VFS developer usage.'
  spec.homepage      = 'https://github.com/department-of-veterans-affairs/vtk'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['documentation_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/department-of-veterans-affairs/vtk/blob/master/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '> 0.20.3'
  spec.add_dependency 'tty-command', '~> 0.10.0'
  spec.add_dependency 'tty-prompt', '~> 0.23.0'
end
