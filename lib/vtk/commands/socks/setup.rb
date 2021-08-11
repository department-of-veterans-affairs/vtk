# frozen_string_literal: true

require_relative '../../command'
require 'tty-prompt'
require 'fileutils'
require 'erb'

module Vtk
  module Commands
    class Socks
      # Sets up socks access to the VA network
      class Setup < Vtk::Command
        require_relative 'setup/check_ssh_key'
        require_relative 'setup/configure_system_boot'
        require_relative 'setup/configure_system_proxy'
        require_relative 'setup/setup_ssh_config'
        require_relative 'setup/test_ssh_connection'
        require_relative 'setup/utils'

        include CheckSshKey
        include ConfigureSystemBoot
        include ConfigureSystemProxy
        include SetupSshConfig
        include TestSshConnection
        include Utils

        ACCESS_REQUEST_TEMPLATE_URL = 'https://github.com/department-of-veterans-affairs/va.gov-team/issues/new?' \
          'assignees=&labels=external-request%2C+operations%2C+ops-access-request&' \
          'template=Environment-Access-Request-Template.md&title=Access+for+%5Bindividual%5D'
        PROXY_URL = 'https://raw.githubusercontent.com/department-of-veterans-affairs/va.gov-team/master/' \
          'scripts/socks/proxy.pac'

        attr_reader :ssh_config_path, :input, :output, :boot_script_path, :ssh_key_path, :prompt, :port, :skip_test

        def initialize(options)
          @options = options
          @prompt = TTY::Prompt.new interrupt: :exit
          @port = options['port'] || '2001'
          @boot_script_path = options['boot_script_path'] || "#{ENV['HOME']}/Library"
          @ssh_key_path = options['ssh_key_path'] || "#{ENV['HOME']}/.ssh/id_rsa_vagov"
          @ssh_config_path = options['ssh_config_path'] || "#{ENV['HOME']}/.ssh/config"
          @skip_test = options['skip_test'] || false

          super()
        end

        def execute(input: $stdin, output: $stdout)
          define_stdin_out_vars input: input, output: output

          setup_ssh_config
          check_ssh_key
          ssh_agent_add

          unless @ssh_key_created
            test_ssh_connection unless skip_test
            configure_system_boot
            configure_system_proxy
          end

          log "SOCKS setup complete. #{'Re-run `vtk socks setup` after your key is approved.' if @ssh_key_created}"
        end

        private

        def define_stdin_out_vars(input:, output:)
          @input = input
          @output = output
        end

        def setup_ssh_config
          create_ssh_directory
          install_ssh_config
          configure_ssh_config_with_keychain
          ssh_config_clean_up
        end

        def ssh_agent_add
          FileUtils.chmod 0o600, ssh_key_path if key_exists?
          FileUtils.chmod 0o600, "#{ssh_key_path}.pub" if public_key_exists?

          if macos?
            `ssh-add -AK 2> /dev/null; ssh-add -AK #{ssh_key_path} 2> /dev/null`
          elsif ubuntu_like?
            `[ -z "$SSH_AUTH_SOCK" ] && eval "$(ssh-agent -s)";
              ssh-add 2> /dev/null; ssh-add #{ssh_key_path} 2> /dev/null`
          end
        end
      end
    end
  end
end
