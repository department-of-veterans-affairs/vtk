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
      def machine
        if options[:help]
          invoke :help, ['machine']
        else
          require_relative 'scan/machine'
          Vtk::Commands::Scan::Machine.new(options).execute
        end
      end

      # Future subcommands:
      # desc 'repos', 'Scan lockfiles for compromised packages'
      # desc 'credentials', 'Inventory credentials that may need rotation'
    end
  end
end
