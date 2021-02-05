# frozen_string_literal: true

require_relative '../../command'
require 'tty-prompt'
require 'fileutils'
require 'open3'

module Vtk
  module Commands
    class Socks
      # Sets up socks access to the VA network
      class Setup < Vtk::Command
        attr_reader :ssh_config_path, :input, :output, :ssh_key_path, :prompt, :port

        def initialize(options)
          @options = options
          @prompt = TTY::Prompt.new interrupt: :exit
          @port = options['port'] || '2001'
          @ssh_key_path = options['ssh_key_path'] || "#{ENV['HOME']}/.ssh/id_rsa_vagov"
          @ssh_config_path = options['ssh_config_path'] || "#{ENV['HOME']}/.ssh/config"

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
          test_connection
          log 'SOCKS has been setup. Run `vtk socks on` to turn on.'
        end

        private

        def check_and_create_key
          return log "#{pretty_ssh_key_path} exists. Skipping." if key_exists?
          return true unless prompt.yes? '----> SSH Key not found. Create one now?'

          create_key
          open_key_access_request
          exit
        end

        def key_exists?
          File.exist? ssh_key_path
        end

        def create_key
          Open3.popen3("ssh-keygen -f #{ssh_key_path}") do |stdin, stdout, stderr, wait_thread|
            Thread.start { IO.copy_stream $stdin, stdin }
            Thread.start { IO.copy_stream stdout, $stdout }
            Thread.start { IO.copy_stream stderr, $stderr }
            wait_thread.join
          end
          # $stdin.cooked! ?
        end

        def open_key_access_request
          url = 'https://github.com/department-of-veterans-affairs/va.gov-team/issues/new?' \
            'assignees=&labels=external-request%2C+operations&template=Environment-Access-Request-Template.md&' \
            'title=Access+for+%5Bindividual%5D'
          `#{macos? ? 'open' : 'xdg-open'} "#{url}"`
          log "You'll have to wait for access approval before continuing. Once approved, re-run `vtk socks setup`."
        end

        def ssh_config_exists?
          File.exist? ssh_config_path
        end

        def ssh_config_configured?
          return false unless ssh_config_exists?
          return true unless prompt.yes? "----> #{pretty_ssh_config_path} exists. Check if configured correctly?"

          download_ssh_config
          ssh_config_local = File.read ssh_config_path
          ssh_config = File.read '/tmp/dova-devops/ssh/config'
          ssh_config_local.include? ssh_config
        end

        def ssh_config_configured_with_keychain?
          return false unless ssh_config_exists?

          ssh_config_local = File.readlines ssh_config_path
          ssh_config_local.grep(/UseKeychain yes/).size.positive?
        end

        def install_ssh_config
          return log "#{pretty_ssh_config_path} configured." if ssh_config_configured?
          return true unless prompt.yes? "----> #{pretty_ssh_config_path} missing or incomplete. Install/replace now?"

          ssh_dir = File.dirname ssh_config_path

          download_ssh_config unless File.exist? '/tmp/dova-devops'
          FileUtils.mkdir_p ssh_dir
          FileUtils.chmod 0o700, ssh_dir
          backup_existing_ssh_config
          FileUtils.cp '/tmp/dova-devops/ssh/config', ssh_config_path
          FileUtils.chmod 0o600, "#{ssh_dir}/config"
        end

        def backup_existing_ssh_config
          return true unless File.exist? ssh_config_path

          if File.exist? "#{ssh_config_path}.bak"
            log "ERROR: Could not make backup of #{pretty_ssh_config_path} as #{pretty_ssh_config_path}.bak exists. " \
              'Aborting.'
            exit 1
          end

          FileUtils.mv ssh_config_path, "#{ssh_config_path}.bak"
        end

        def configure_ssh_config_with_keychain
          return unless macos?
          return if ssh_config_configured_with_keychain?
          return true unless prompt.yes? "----> #{pretty_ssh_config_path} missing Keychain configuration. Add now?"

          keychain_config = <<~CFG

            # Maintain SSH keys in macOS Keychain
            Host *
              UseKeychain yes
              AddKeysToAgent yes
              IdentityFile #{pretty_ssh_key_path}
          CFG

          IO.write ssh_config_path, keychain_config, mode: 'a'
        end

        def download_ssh_config
          log 'Downloading ssh/config.'

          repo_url = 'https://github.com/department-of-veterans-affairs/devops.git'
          `git clone --quiet#{' --depth 1' if macos?} --no-checkout --filter=blob:none #{repo_url} /tmp/dova-devops`
          `cd /tmp/dova-devops; git checkout master -- ssh/config`
        end

        def ssh_config_clean_up
          FileUtils.rm_rf '/tmp/dova-devops'
        end

        def ssh_agent_add
          if macos?
            `ssh-add -K 2> /dev/null; ssh-add -K #{ssh_key_path} 2> /dev/null`
          elsif ubuntu?
            `[ -z "$SSH_AUTH_SOCK" ] && eval "$(ssh-agent -s)";
              ssh-add 2> /dev/null; ssh-add #{ssh_key_path} 2> /dev/null`
          end
        end

        def test_connection
          return true unless prompt.yes? '----> Test SOCKS connection now?'

          ssh_output = `ssh -F #{ssh_config_path} -o ConnectTimeout=5 -q socks -D #{port} exit`.chomp
          if ssh_output == 'This account is currently not available.'
            log 'SSH Connection to SOCKS server successful.'
          else
            log 'ERROR: SSH Connection to SOCKS server unsuccessful. Error message:'
            output.puts `ssh -F #{ssh_config_path} -o ConnectTimeout=5 -vvv socks -D #{port} -N`
            exit 1
          end
        end

        def macos?
          RUBY_PLATFORM.include? 'darwin'
        end

        def ubuntu?
          return false unless File.exist? '/etc/lsb-release'

          File.readlines('/etc/lsb-release').each { |line| return true if line =~ /^DISTRIB_ID=Ubuntu/ }

          false
        end

        def pretty_ssh_config_path
          pretty_path ssh_config_path
        end

        def pretty_ssh_key_path
          pretty_path ssh_key_path
        end

        def pretty_path(path)
          path.gsub ENV['HOME'], '~'
        end

        def log(message)
          output.puts "----> #{message}"
        end
      end
    end
  end
end
