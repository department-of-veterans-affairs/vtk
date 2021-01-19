# frozen_string_literal: true

require 'thor'

module Vtk
  module Commands
    # Interfaces with vets-api modules
    class Module < Thor
      namespace :module

      desc 'service <module name>', 'Add new service class to a module in vets-api'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def service(name)
        if options[:help]
          invoke :help, ['service']
        else
          require_relative 'module/service'
          Vtk::Commands::Module::Service.new(name, options).execute
        end
      end

      desc 'serializer <module name>', 'Add new serializer to a module in vets-api'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def serializer(name)
        if options[:help]
          invoke :help, ['serializer']
        else
          require_relative 'module/serializer'
          Vtk::Commands::Module::Serializer.new(name, options).execute
        end
      end

      desc 'model <module name>', 'Add new model to a module in vets-api'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def model(name)
        if options[:help]
          invoke :help, ['model']
        else
          require_relative 'module/model'
          Vtk::Commands::Module::Model.new(name, options).execute
        end
      end

      desc 'controller <module name>', 'Add new controller to a module in vets-api'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def controller(name)
        if options[:help]
          invoke :help, ['controller']
        else
          require_relative 'module/controller'
          Vtk::Commands::Module::Controller.new(name, options).execute
        end
      end

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
