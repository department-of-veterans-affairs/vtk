# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Module
      # Adds a new module serializer to vets-api
      class Serializer < Vtk::Command
        attr_accessor :name, :options

        def initialize(name, options)
          @name = name
          @options = options

          super()
        end

        def execute(_input: $stdin, _output: $stdout)
          create_serializer(name)
        end

        private

        def create_controller(name)
          `rails g module_component #{name} serializer`
        end
      end
    end
  end
end
