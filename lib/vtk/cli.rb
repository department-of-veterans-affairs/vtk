# frozen_string_literal: true

require 'thor'

module Vtk
  # Handle the application command line parsing
  # and the dispatch to various command objects
  #
  # @api public
  class CLI < Thor
    # Error raised by this runner
    Error = Class.new(StandardError)

    desc 'version', 'vtk version'
    def version
      require_relative 'version'
      puts "v#{Vtk::VERSION}"
    end
    map %w[--version -v] => :version

    require_relative 'commands/socks'
    register Vtk::Commands::Socks, 'socks', 'socks [SUBCOMMAND]', 'Handles connecting to VA network via SOCKS'

    require_relative 'commands/module'
    register Vtk::Commands::Module, 'module', 'module [SUBCOMMAND]', 'Command description...'
  end
end
