# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Socks
      # Turns off SOCKS connection to VA network
      class Off < Vtk::Command
        def initialize(options)
          @options = options

          super()
        end

        def execute(_input: $stdin, output: $stdout)
          `lsof -Pi :2001 -sTCP:LISTEN -t | xargs kill`
          # TODO: ensure connection closed
          output.puts '----> Disconnected from SOCKS.'
        end
      end
    end
  end
end
