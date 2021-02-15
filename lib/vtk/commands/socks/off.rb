# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Socks
      # Turns off SOCKS connection to VA network
      class Off < Vtk::Command
        attr_reader :options

        def initialize(options)
          @options = options

          super()
        end

        def execute(_input: $stdin, output: $stdout)
          pids_killed = running_pids.map { |pid| kill_pid pid }

          if pids_killed.any? && pids_killed.all?
            output.puts '----> Disconnected from SOCKS.'
          else
            output.puts '----> No SOCKS connection found.'
          end
        end

        private

        def running_pids
          `lsof -Pi :#{options['port'] || 2001} -sTCP:LISTEN -t`.chomp.split "\n"
        end

        def kill_pid(pid)
          system "kill -9 #{pid}"
        end
      end
    end
  end
end
