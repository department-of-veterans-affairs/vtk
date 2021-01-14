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

        def execute(_input: $stdin, _output: $stdout)
          create_module name
        end

        private

        def create_module(name)
          # create a new module from the vets-api generator
          if(`gem which rails` == "")
            output.puts 'Rails is a dependency of this command and was not found, please install Rails'
          else
            `rails g module #{name}`
          end
        end
      end
    end
  end
end
