# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Socks
      # Turns on SOCKS connection to VA network
      class On < Vtk::Command
        attr_reader :input, :output

        def initialize(options)
          @options = options

          super()
        end

        def execute(_input: $stdin, output: $stdout)
          @input = input
          @output = output

          return output.puts '----> Already connected to SOCKS.' if connected?

          ensure_host_authenticity
          connect_to_socks
          ensure_connection
        end

        private

        def connected?
          system 'nscurl http://sentry.vfs.va.gov 2> /dev/null | grep -q sentry-logo'
        end

        def ensure_host_authenticity
          `ssh -q socks -D 2001 exit | grep -v "This account is currently not available." || true`
        end

        def connect_to_socks
          Process.fork do
            `lsof -Pi :2001 -sTCP:LISTEN -t > /dev/null || ssh -o ServerAliveInterval=60 socks -D 2001 -N`
          end
        end

        def ensure_connection
          output.print '----> Connecting'
          10.times do
            sleep 1
            output.print '.'
            next unless connected?

            return output.puts "\r----> Connected to SOCKS."
          end

          output.puts "\r----> ERROR: Could not connect to SOCKS."
        end
      end
    end
  end
end
