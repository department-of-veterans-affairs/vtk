# frozen_string_literal: true

require 'thor'

module Vtk
  module Commands
    # Security scanning commands for developer machines and repositories
    class Scan < Thor
      namespace :scan

      desc 'machine', 'Check for active malware infection indicators (Shai-Hulud)'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :verbose, aliases: '-v', type: :boolean,
                              desc: 'Detailed output with all checks'
      method_option :json, aliases: '-j', type: :boolean,
                           desc: 'Output results as JSON'
      method_option :quiet, aliases: '-q', type: :boolean,
                            desc: 'Exit code only, no output'
      method_option :scan_dirs, type: :string,
                                desc: 'Additional directories to scan for backdoor workflows (comma-separated)'
      def machine
        if options[:help]
          invoke :help, ['machine']
        else
          require_relative 'scan/machine'
          exit_status = Vtk::Commands::Scan::Machine.new(options).execute
          exit exit_status
        end
      end

      desc 'repo [PATH]', 'Scan a repository for compromised packages'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :refresh, aliases: '-r', type: :boolean,
                              desc: 'Force refresh of compromised packages list'
      method_option :json, aliases: '-j', type: :boolean,
                           desc: 'Output results as JSON'
      method_option :quiet, aliases: '-q', type: :boolean,
                            desc: 'Exit code only, no output'
      def repo(path = nil)
        if options[:help]
          invoke :help, ['repo']
        else
          require_relative 'scan/repo'
          exit_status = Vtk::Commands::Scan::Repo.new(path, options).execute
          exit exit_status
        end
      end

      # Future subcommands:
      # desc 'repos', 'Scan all Node.js projects in common directories'
      # desc 'credentials', 'Inventory credentials that may need rotation'
    end
  end
end
