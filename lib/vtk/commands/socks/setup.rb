# frozen_string_literal: true

require_relative '../../command'
require 'tty-prompt'
require 'fileutils'

module Vtk
  module Commands
    class Socks
      # Sets up socks access to the VA network
      class Setup < Vtk::Command
        attr_reader :input, :output, :prompt

        def initialize(options)
          @options = options
          @prompt = TTY::Prompt.new

          super()
        end

        def execute(input: $stdin, output: $stdout)
          @input = input
          @output = output

          check_and_create_key
          install_ssh_config
          configure_ssh_config_with_keychain
          ssh_config_clean_up
          ssh_agent_add
          log 'SOCKS has been setup. Run `vtk socks on` to turn on.'
        end

        private

        def check_and_create_key
          return log '~/.ssh/id_rsa_vagov exists. Skipping.' if key_exists?
          return true unless prompt.yes? '----> SSH Key not found. Create one now?'

          create_key
          open_key_access_request
          exit
        end

        def key_exists?
          File.exist? "#{ENV['HOME']}/.ssh/id_rsa_vagov"
        end

        def create_key
          `ssh-keygen -f ~/.ssh/id_rsa_vagov`
        end

        def open_key_access_request
          `open "https://github.com/department-of-veterans-affairs/va.gov-team/issues/new?" \
            "assignees=&labels=external-request%2C+operations&template=Environment-Access-Request-Template.md&" \
            "title=Access+for+%5Bindividual%5D"`
          log "You'll have to wait for access approval before continuing."
        end

        def ssh_config_exists?
          File.exist? "#{ENV['HOME']}/.ssh/config"
        end

        def ssh_config_configured?
          return false unless ssh_config_exists?
          return true unless prompt.yes? '----> ~/.ssh/config exists. Check if configured correctly?'

          download_ssh_config
          ssh_config_local = File.read "#{ENV['HOME']}/.ssh/config"
          ssh_config = File.read '/tmp/devops/ssh/config'
          ssh_config_local.include? ssh_config
        end

        def ssh_config_configured_with_keychain?
          return false unless ssh_config_exists?

          ssh_config_local = File.readlines "#{ENV['HOME']}/.ssh/config"
          ssh_config_local.grep(/UseKeychain yes/).size.positive?
        end

        def install_ssh_config
          return log '~/.ssh/config configured.' if ssh_config_configured?
          return true unless prompt.yes? '----> ~/.ssh/config missing or incomplete. Install/replace now?'

          ssh_dir = "#{ENV['HOME']}/.ssh"

          download_ssh_config unless File.exist? '/tmp/devops'
          FileUtils.mkdir_p ssh_dir
          FileUtils.chmod 0o700, ssh_dir
          FileUtils.cp '/tmp/devops/ssh/config', "#{ssh_dir}/config"
          FileUtils.chmod 0o600, "#{ssh_dir}/config"
        end

        def configure_ssh_config_with_keychain
          return unless RUBY_PLATFORM.include? 'darwin'
          return if ssh_config_configured_with_keychain?
          return true unless prompt.yes? '----> ~/.ssh/config missing Keychain configuration. Add now?'

          keychain_config = <<~CFG

            # Maintain SSH keys in macOS Keychain
            Host *
              UseKeychain yes
              AddKeysToAgent yes
              IdentityFile ~/.ssh/id_rsa_vagov
          CFG

          IO.write "#{ENV['HOME']}/.ssh/config", keychain_config, mode: 'a'
        end

        def download_ssh_config
          log 'Downloading ssh/config.'

          repo_url = 'https://github.com/department-of-veterans-affairs/devops.git'
          `git clone --quiet --depth 1 --no-checkout --filter=blob:none #{repo_url} /tmp/devops`
          `cd /tmp/devops; git checkout master -- ssh/config`
        end

        def ssh_config_clean_up
          FileUtils.rm_rf '/tmp/devops'
        end

        def ssh_agent_add
          `ssh-add -K 2> /dev/null`
          `ssh-add -K ~/.ssh/id_rsa_vagov 2> /dev/null`
        end

        def log(message)
          output.puts "----> #{message}"
        end
      end
    end
  end
end
