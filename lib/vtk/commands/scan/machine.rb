# frozen_string_literal: true

require 'English'
require_relative '../../command'

module Vtk
  module Commands
    class Scan
      # Check for active malware infection indicators (Shai-Hulud)
      class Machine < Vtk::Command
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
          output.puts 'ERROR: Could not find shai-hulud-machine-check.sh script'
          output.puts "Expected at: #{gem_root}/scripts/shai-hulud-machine-check.sh"
          1
        end

        def run_script(script_path)
          cmd = ['bash', script_path]
          cmd << '--verbose' if options[:verbose]
          cmd << '--json' if options[:json]
          cmd << '--quiet' if options[:quiet]

          system(*cmd)
          $CHILD_STATUS.exitstatus
        end

        def find_script
          # Look for script relative to this gem's location
          # __dir__ = lib/vtk/commands/scan, so go up 4 levels to get to vtk root
          gem_root = File.expand_path('../../../..', __dir__)
          script_path = File.join(gem_root, 'scripts', 'shai-hulud-machine-check.sh')

          # Use explicit bash interpreter, so executable bit not required
          return [script_path, gem_root] if File.exist?(script_path)

          [nil, gem_root]
        end
      end
    end
  end
end
