# frozen_string_literal: true

require 'thor'

module Vtk
  module Commands
    # Handles connecting to VA network via SOCKS
    class Socks < Thor
      namespace :socks

      desc 'setup', 'Command description...'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def setup(*)
        if options[:help]
          invoke :help, ['setup']
        else
          require_relative 'socks/setup'
          Vtk::Commands::Socks::Setup.new(options).execute
        end
      end

      desc 'off', 'Disconnects from VA SOCKS'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :port, aliases: '-p', type: :string,
                           desc: 'Port that SOCKS server is running on'
      def off(*)
        if options[:help]
          invoke :help, ['off']
        else
          require_relative 'socks/off'
          Vtk::Commands::Socks::Off.new(options).execute
        end
      end

      desc 'on', 'Connects to VA SOCKS'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :port, aliases: '-p', type: :string,
                           desc: 'Port to run SOCKS server on'
      def on(*)
        if options[:help]
          invoke :help, ['on']
        else
          require_relative 'socks/on'
          Vtk::Commands::Socks::On.new(options).execute
        end
      end
    end
  end
end
