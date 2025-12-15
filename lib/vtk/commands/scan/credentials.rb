# frozen_string_literal: true

require 'English'
require_relative '../../command'

module Vtk
  module Commands
    class Scan
      # Audit credentials that may have been accessed by Shai-Hulud malware
      class Credentials < Vtk::Command
        attr_reader :options

        def initialize(options)
          @options = options
          super()
        end

        def execute(output: $stdout)
          @output = output

          script_path, gem_root = find_script
          return script_not_found(output, gem_root) unless script_path

          run_script(script_path)
        end

        private

        def script_not_found(output, gem_root)
          output.puts 'ERROR: Could not find credential-audit.sh script'
          output.puts "Expected at: #{gem_root}/scripts/credential-audit.sh"
          1
        end

        OPTION_FLAGS = {
          verbose: '--verbose',
          json: '--json'
        }.freeze

        def run_script(script_path)
          cmd = ['bash', script_path]
          cmd += OPTION_FLAGS.filter_map { |key, flag| flag if options[key] }

          system(*cmd)
          $CHILD_STATUS.exitstatus
        end

        def find_script
          gem_root = File.expand_path('../../../..', __dir__)
          script_path = File.join(gem_root, 'scripts', 'credential-audit.sh')

          return [script_path, gem_root] if File.exist?(script_path)

          [nil, gem_root]
        end
      end
    end
  end
end
