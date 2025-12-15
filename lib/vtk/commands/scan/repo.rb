# frozen_string_literal: true

require 'English'
require_relative '../../command'

module Vtk
  module Commands
    class Scan
      # Scan a repository for compromised packages and backdoor workflows
      # Shells out to shai-hulud-repo-check.sh for the actual scanning
      class Repo < Vtk::Command
        attr_reader :options, :path

        def initialize(path, options)
          @path = path || Dir.pwd
          @options = options
          super()
        end

        def execute(output: $stdout)
          @output = output

          unless File.directory?(@path)
            output.puts "ERROR: Directory not found: #{@path}"
            return 1
          end

          script_path, gem_root = find_script
          return script_not_found(output, gem_root) unless script_path

          run_script(script_path)
        end

        private

        def script_not_found(output, gem_root)
          output.puts 'ERROR: Could not find shai-hulud-repo-check.sh script'
          output.puts "Expected at: #{gem_root}/scripts/shai-hulud-repo-check.sh"
          1
        end

        def run_script(script_path)
          cmd = ['bash', script_path] + script_options + [@path]
          system(*cmd)
          $CHILD_STATUS.exitstatus
        end

        OPTION_FLAGS = {
          refresh: '--refresh',
          json: '--json',
          quiet: '--quiet',
          verbose: '--verbose',
          recursive: '--recursive'
        }.freeze

        def script_options
          flags = OPTION_FLAGS.filter_map { |key, flag| flag if options[key] }
          flags << "--depth=#{options[:depth]}" if options[:depth]
          flags
        end

        def find_script
          # Look for script relative to this gem's location
          # __dir__ = lib/vtk/commands/scan, so go up 4 levels to get to vtk root
          gem_root = File.expand_path('../../../..', __dir__)
          script_path = File.join(gem_root, 'scripts', 'shai-hulud-repo-check.sh')

          # Use explicit bash interpreter, so executable bit not required
          return [script_path, gem_root] if File.exist?(script_path)

          [nil, gem_root]
        end
      end
    end
  end
end
