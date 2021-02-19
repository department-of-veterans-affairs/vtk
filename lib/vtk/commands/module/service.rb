# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Module
      # Adds a new module service class to vets-api
      class Service < Vtk::Command
        attr_accessor :name, :options

        def initialize(name, options)
          @name = name
          @options = options

          super()
        end

        def execute(_input: $stdin, _output: $stdout)
          create_service(name, options)
        end

        private

        def create_service(name, options)
          component_name = options[:component_name] || name
          system("rails g module_component #{name} method:service component_name:#{component_name}")
        end
      end
    end
  end
end
