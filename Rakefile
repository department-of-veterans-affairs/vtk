# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Tags version, pushes to remote, and pushes gem'
task :release do
  sh 'git', 'tag', "v#{Vtk::VERSION}"
  sh 'git push origin master'
  sh "git push origin v#{Vtk::VERSION}"
  sh 'rake build'
  sh 'ls pkg/*.gem | xargs -n 1 gem push'
end