# frozen_string_literal: true

require 'English'
require_relative '../../command'

module Vtk
  module Commands
    class Scan
      # Trace direct and transitive uses of GitHub Actions across an org.
      # Shells out to gh-action-trace.sh for the actual work.
      class Actions < Vtk::Command
        BOOLEAN_FLAGS = {
          external: '--external',
          quiet: '--quiet',
          verbose: '--verbose'
        }.freeze

        VALUE_FLAGS = {
          org: '--org',
          depth: '--depth',
          format: '--format',
          output: '--output',
          check_runs: '--check-runs'
        }.freeze

        attr_reader :options

        def initialize(options)
          @options = options
          super()
        end

        def execute(output: $stdout)
          error = validation_error
          return error_out(output, error) if error

          script_path, gem_root = find_script
          return script_not_found(output, gem_root) unless script_path

          run_script(script_path)
        end

        private

        def validation_error
          return 'ERROR: --org is required' if blank?(options[:org])
          return 'ERROR: --action is required (at least one)' if blank?(options[:action])

          nil
        end

        def blank?(value)
          value.nil? || value.to_s.empty? || (value.respond_to?(:empty?) && value.empty?)
        end

        def error_out(output, message)
          output.puts message
          1
        end

        def script_not_found(output, gem_root)
          output.puts 'ERROR: Could not find gh-action-trace.sh script'
          output.puts "Expected at: #{gem_root}/scripts/gh-action-trace.sh"
          1
        end

        def run_script(script_path)
          cmd = ['bash', script_path] + script_options
          system(*cmd)
          $CHILD_STATUS.exitstatus
        end

        def script_options
          boolean_script_flags + value_script_flags + action_script_flags
        end

        def boolean_script_flags
          BOOLEAN_FLAGS.select { |key, _| options[key] }.values
        end

        def value_script_flags
          VALUE_FLAGS.flat_map do |key, flag|
            value = options[key]
            blank?(value) ? [] : [flag, value.to_s]
          end
        end

        def action_script_flags
          Array(options[:action]).flat_map { |action| ['--action', action] }
        end

        def find_script
          # __dir__ = lib/vtk/commands/scan, so go up 4 levels to the gem root
          gem_root = File.expand_path('../../../..', __dir__)
          script_path = File.join(gem_root, 'scripts', 'gh-action-trace.sh')
          return [script_path, gem_root] if File.exist?(script_path)

          [nil, gem_root]
        end
      end
    end
  end
end
