# frozen_string_literal: true

require 'thor'

module Vtk
  module Commands
    # Interfaces with vets-api modules
    class Module < Thor
      namespace :module

      desc 'add <module name>', 'Add a new module to vets-api'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def add(name)
        if options[:help]
          invoke :help, ['add']
        else
          require_relative 'module/add'
          Vtk::Commands::Module::Add.new(name, options).execute
        end
      end
    end
  end
end
