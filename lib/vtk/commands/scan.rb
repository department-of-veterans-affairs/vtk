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
      method_option :refresh, type: :boolean,
                              desc: 'Force refresh of compromised packages list'
      method_option :json, aliases: '-j', type: :boolean,
                           desc: 'Output results as JSON'
      method_option :quiet, aliases: '-q', type: :boolean,
                            desc: 'Exit code only, no output'
      method_option :verbose, aliases: '-v', type: :boolean,
                              desc: 'Show each lockfile as it is scanned'
      method_option :recursive, aliases: '-r', type: :boolean,
                                desc: 'Recursively scan subdirectories (default depth: 5)'
      method_option :depth, type: :numeric, default: 5,
                            desc: 'Max directory depth for recursive scan (0=unlimited)'
      def repo(path = nil)
        if options[:help]
          invoke :help, ['repo']
        else
          require_relative 'scan/repo'
          exit_status = Vtk::Commands::Scan::Repo.new(path, options).execute
          exit exit_status
        end
      end

      desc 'credentials', 'Audit credentials that may need rotation after a security incident'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :verbose, aliases: '-v', type: :boolean,
                              desc: 'Show all checks including clean ones'
      method_option :json, aliases: '-j', type: :boolean,
                           desc: 'Output results as JSON'
      def credentials
        if options[:help]
          invoke :help, ['credentials']
        else
          require_relative 'scan/credentials'
          exit_status = Vtk::Commands::Scan::Credentials.new(options).execute
          exit exit_status
        end
      end

      desc 'actions', 'Trace direct and transitive uses of GitHub Actions across an org'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :org, type: :string, required: false,
                          desc: 'GitHub org to search (required)'
      method_option :action, type: :array, default: [],
                             desc: 'Action to trace; repeat to trace multiple (required)'
      method_option :depth, type: :numeric,
                            desc: 'Max recursion depth for shared workflows (default: 2)'
      method_option :format, type: :string,
                             desc: 'Output format: text, json, csv, both (default: both)'
      method_option :external, type: :boolean,
                               desc: 'Also search all of GitHub for external shared workflows (slower)'
      method_option :output, type: :string,
                             desc: 'Write report output to file (JSON or CSV depending on --format)'
      method_option :check_runs, type: :string,
                                 desc: 'Check workflow run history during ISO 8601 window (FROM..TO, TO optional)'
      method_option :quiet, aliases: '-q', type: :boolean,
                            desc: 'Suppress progress output'
      method_option :verbose, aliases: '-v', type: :boolean,
                              desc: 'Show detailed debug info'
      def actions
        if options[:help]
          invoke :help, ['actions']
        else
          require_relative 'scan/actions'
          exit_status = Vtk::Commands::Scan::Actions.new(options).execute
          exit exit_status
        end
      end
    end
  end
end
