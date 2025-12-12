# frozen_string_literal: true

require 'stringio'
require_relative '../../command'
require_relative '../../cache'
require_relative '../../lockfile_parser'

module Vtk
  module Commands
    class Scan
      # Scan a repository for compromised packages and backdoor workflows
      class Repo < Vtk::Command
        PLAYBOOK_URL = 'https://va.ghe.com/software/Engineering-Excellence-Response-Team/blob/main/docs/shai-hulud-repo-owner-playbook.md'

        attr_reader :options, :path

        def initialize(path, options)
          @path = path || Dir.pwd
          @options = options
          super()
        end

        def execute(output: $stdout)
          @output = output
          @findings = { compromised: [], backdoors: [], warnings: [] }

          unless File.directory?(@path)
            output.puts "ERROR: Directory not found: #{@path}"
            return 1
          end

          run_checks
          report_findings

          exit_code
        end

        private

        def run_checks
          check_lockfiles
          check_backdoor_workflows
        end

        def check_lockfiles
          lockfiles = LockfileParser.find_lockfiles(@path)

          if lockfiles.empty?
            @findings[:warnings] << 'No lockfiles found (package-lock.json, yarn.lock, or pnpm-lock.yaml)'
            return
          end

          compromised_packages = Cache.compromised_packages(
            refresh: options[:refresh],
            output: options[:quiet] ? StringIO.new : @output
          )

          lockfiles.each do |lockfile|
            packages = LockfileParser.parse(lockfile)
            packages.each do |pkg|
              @findings[:compromised] << { lockfile: lockfile, package: pkg } if compromised_packages.include?(pkg)
            end
          end
        end

        def check_backdoor_workflows
          # Check for discussion.yaml backdoor
          discussion_workflow = File.join(@path, '.github', 'workflows', 'discussion.yaml')
          discussion_workflow_yml = File.join(@path, '.github', 'workflows', 'discussion.yml')

          [discussion_workflow, discussion_workflow_yml].each do |workflow_path|
            next unless File.exist?(workflow_path)

            content = File.read(workflow_path)
            # Check for malicious patterns: discussion trigger + self-hosted + unescaped body
            next unless content.include?('discussion') &&
                        content.include?('self-hosted') &&
                        content =~ /\$\{\{\s*github\.event\.discussion\.body\s*\}\}/

            @findings[:backdoors] << { file: workflow_path, type: 'discussion_backdoor' }
          end

          # Check for formatter_*.yml secrets extraction workflows
          workflows_dir = File.join(@path, '.github', 'workflows')
          return unless File.directory?(workflows_dir)

          Dir.glob(File.join(workflows_dir, 'formatter_*.yml')).each do |workflow|
            @findings[:backdoors] << { file: workflow, type: 'secrets_extraction' }
          end
        end

        def report_findings
          return if options[:quiet]

          if options[:json]
            report_json
          else
            report_text
          end
        end

        def report_json
          require 'json'
          result = {
            path: @path,
            status: status_label,
            compromised_packages: @findings[:compromised],
            backdoors: @findings[:backdoors],
            warnings: @findings[:warnings]
          }
          @output.puts JSON.pretty_generate(result)
        end

        def report_text
          @output.puts "Scanning: #{@path}"
          @output.puts

          report_compromised_packages
          report_backdoors
          report_warnings
          report_status
        end

        def report_compromised_packages
          return unless compromised?

          @output.puts '🚨 COMPROMISED PACKAGES FOUND:'
          @findings[:compromised].each do |finding|
            @output.puts "   #{finding[:package]}"
            @output.puts "   └─ in #{finding[:lockfile]}"
          end
          @output.puts
        end

        def report_backdoors
          return unless backdoors?

          @output.puts '🚨 BACKDOOR WORKFLOWS FOUND:'
          @findings[:backdoors].each do |finding|
            @output.puts "   #{finding[:file]}"
            @output.puts "   └─ Type: #{finding[:type]}"
          end
          @output.puts
        end

        def report_warnings
          return if compromised? || backdoors? || @findings[:warnings].empty?

          @findings[:warnings].each do |warning|
            @output.puts "⚠️  #{warning}"
          end
          @output.puts
        end

        def report_status
          @output.puts "Status: #{status_label}"
          return unless compromised? || backdoors?

          @output.puts
          @output.puts 'See cleanup playbook:'
          @output.puts "  #{PLAYBOOK_URL}"
        end

        def compromised?
          @findings[:compromised].any?
        end

        def backdoors?
          @findings[:backdoors].any?
        end

        def status_label
          if compromised?
            'INFECTED - Compromised packages found'
          elsif backdoors?
            'WARNING - Backdoor workflows found'
          else
            'CLEAN'
          end
        end

        def exit_code
          if compromised?
            1
          elsif backdoors?
            2
          else
            0
          end
        end
      end
    end
  end
end
