# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Module
      # Adds a new module to vets-api
      class Add < Vtk::Command
        attr_accessor :name, :options

        def initialize(name, options)
          @name = name
          @options = options

          super()
        end

        def execute(_input: $stdin, output: $stdout)
          `rails g module #{name}`
          output.puts 'OK'
        end
      end
    end
  end
end
