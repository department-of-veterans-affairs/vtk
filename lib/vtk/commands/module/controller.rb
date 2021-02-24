# frozen_string_literal: true

require_relative '../../command'

module Vtk
  module Commands
    class Module
      # Adds a new module controller to vets-api
      class Controller < Vtk::Command
        attr_accessor :name, :options

        def initialize(name, options)
          @name = name
          @options = options

          super()
        end

        def execute(_input: $stdin, _output: $stdout)
          create_controller(name, options)
        end

        private

        def create_controller(name, options)
          module_name = options[:module_name]
          system("rails g module_component #{module_name} method:controller component_name:#{name}")
        end
      end
    end
  end
end
