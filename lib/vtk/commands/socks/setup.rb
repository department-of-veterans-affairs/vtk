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
          @input = input
          @output = output

          setup_ssh_config
          check_ssh_key
          ssh_agent_add

          test_ssh_connection unless skip_test

          configure_system_boot
          configure_system_proxy

          test_http_connection unless skip_test

          log 'SOCKS setup complete.'
        end

        private

        def check_ssh_key
          return true if key_exists?

          generate_key_and_open_key_access_request
        end

        def key_exists?
          File.exist? ssh_key_path
        end

        def public_key_exists?
          File.exist? "#{ssh_key_path}.pub"
        end

        def generate_key_and_open_key_access_request
          log 'VA key missing. Generating now...'
          system "ssh-keygen -f #{ssh_key_path} #{'-N ""' if ENV['TEST']}"

          if prompt.yes?(copy_and_open_gh)
            copy_key_to_clipboard
            `#{'xdg-' unless macos?}open "#{access_request_template_url}" 2> /dev/null`
          else
            log "You'll need to submit ~/.ssh/id_rsa_vagov.pub for approval to: #{access_request_template_url}."
            exit 1 unless prompt.yes? 'Continue setup?'
          end
        end

        def copy_key_to_clipboard
          ssh_key_contents = File.read "#{ssh_key_path}.pub"

          if macos?
            copy_command = 'pbcopy'
          elsif ubuntu_like?
            system 'sudo apt-get install -y xsel' if `which xsel`.empty?
            copy_command = 'xsel --clipboard'
          end

          IO.popen(copy_command, 'w') { |f| f << ssh_key_contents }
        end

        def access_request_template_url
          'https://github.com/department-of-veterans-affairs/va.gov-team/issues/new?' \
            'assignees=&labels=external-request%2C+operations&template=Environment-Access-Request-Template.md&' \
            'title=Access+for+%5Bindividual%5D'
        end

        def copy_and_open_gh
          '----> An SSH key has been created. Would you like to copy the key to your clipboard and open the access ' \
            'request issue in GitHub now?'
        end

        def setup_ssh_config
          create_ssh_directory
          install_ssh_config
          configure_ssh_config_with_keychain
          ssh_config_clean_up
        end

        def install_ssh_config
          return true if ssh_config_configured?

          if ssh_config_exists? && !prompt.yes?("----> #{pretty_ssh_config_path} incomplete. Backup and replace now?")
            return false
          end

          log 'Installing SSH config...'

          download_ssh_config unless File.exist? '/tmp/dova-devops'
          backup_existing_ssh_config
          FileUtils.cp '/tmp/dova-devops/ssh/config', ssh_config_path
          FileUtils.chmod 0o600, "#{File.dirname ssh_config_path}/config"
        end

        def ssh_config_configured?
          return false unless ssh_config_exists?

          download_ssh_config
          ssh_config_local = File.read ssh_config_path
          ssh_config = File.read '/tmp/dova-devops/ssh/config'
          ssh_config_local.include? ssh_config
        end

        def ssh_config_exists?
          File.exist? ssh_config_path
        end

        def download_ssh_config
          install_git

          ssh_config_clean_up

          ssh_agent_add
          cloned = system(
            "git clone --quiet#{' --depth 1' if macos?} --no-checkout --filter=blob:none #{repo_url} '/tmp/dova-devops'"
          )
          exit 1 unless cloned

          `cd /tmp/dova-devops; git checkout master -- ssh/config`
        end

        def install_git
          if macos?
            install_brew
          elsif ubuntu_like?
            return true unless `which git`.empty?

            system 'sudo apt-get install -y git'
          end
        end

        def install_brew
          return false unless macos?

          installed = !`which brew`.empty?
          return true if installed

          log 'Homebrew not installed. Installing now...'
          system '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        end

        def ssh_config_clean_up
          FileUtils.rm_rf '/tmp/dova-devops'
        end

        def repo_url
          @repo_url ||= begin
            keyscan_github_com

            if github_ssh_configured
              'git@github.com:department-of-veterans-affairs/devops.git'
            else
              'https://github.com/department-of-veterans-affairs/devops.git'
            end
          end
        end

        def keyscan_github_com
          return true if File.exist?('~/.ssh/known_hosts') && !`ssh-keygen -F github.com`.empty?

          `ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2> /dev/null`
        end

        def github_ssh_configured
          !`ssh -T git@github.com 2>&1`.include?('Permission denied')
        end

        def backup_existing_ssh_config
          return true unless ssh_config_exists?

          if File.exist? "#{ssh_config_path}.bak"
            log "!!! ERROR: Could not make backup of #{pretty_ssh_config_path} as #{pretty_ssh_config_path}.bak " \
              'exists. Aborting.'
            exit 1
          end

          FileUtils.mv ssh_config_path, "#{ssh_config_path}.bak"
        end

        def create_ssh_directory
          ssh_dir = File.dirname ssh_config_path
          FileUtils.mkdir_p ssh_dir
          FileUtils.chmod 0o700, ssh_dir
        end

        def configure_ssh_config_with_keychain
          return unless macos?
          return if ssh_config_configured_with_keychain?

          keychain_config = <<~CFG

            # Maintain SSH keys in macOS Keychain
            Host *
              UseKeychain yes
              AddKeysToAgent yes
              IdentityFile #{pretty_ssh_key_path}
          CFG

          IO.write ssh_config_path, keychain_config, mode: 'a'
        end

        def ssh_config_configured_with_keychain?
          return false unless ssh_config_exists?

          ssh_config_local = File.readlines ssh_config_path
          ssh_config_local.grep(/UseKeychain yes/).size.positive?
        end

        def ssh_agent_add
          FileUtils.chmod 0o600, ssh_key_path if key_exists?
          FileUtils.chmod 0o600, "#{ssh_key_path}.pub" if public_key_exists?

          if macos?
            `ssh-add -K 2> /dev/null; ssh-add -K #{ssh_key_path} 2> /dev/null`
          elsif ubuntu_like?
            `[ -z "$SSH_AUTH_SOCK" ] && eval "$(ssh-agent -s)";
              ssh-add 2> /dev/null; ssh-add #{ssh_key_path} 2> /dev/null`
          end
        end

        def test_ssh_connection
          output.print '----> Testing SOCKS SSH connection...'

          add_ip_to_known_hosts

          ssh_output = `ssh -i #{ssh_key_path} -F #{ssh_config_path} -o ConnectTimeout=5 -q socks -D #{port} exit 2>&1`

          if ssh_output.include? 'This account is currently not available.'
            output.puts ' ✅'
          else
            check_ssh_error ssh_output
            exit 1
          end
        end

        def add_ip_to_known_hosts
          jump_box_ip = `grep -A 2 'Host socks' ~/.ssh/config | grep ProxyCommand | awk '{print $6}'`.chomp
          socks_ip = `grep -A 2 'Host socks' ~/.ssh/config | grep HostName | awk '{print $2}'`.chomp

          return unless `ssh-keygen -F #{socks_ip}`.empty?

          `ssh-keyscan -H #{jump_box_ip} >> ~/.ssh/known_hosts 2> /dev/null`
          `ssh -i #{ssh_key_path} dsva@#{jump_box_ip} 'ssh-keyscan -H #{socks_ip}' >> ~/.ssh/known_hosts 2> /dev/null`
        end

        def check_ssh_error(ssh_output)
          if ssh_output.include? 'Permission denied (publickey)'
            @skip_test = true
            output.puts '⚠️  WARN: SSH key is not approved yet. Once it is, re-run `vtk socks setup`.'
          else
            ssh_command = "ssh -i #{ssh_key_path} -F #{ssh_config_path} -o ConnectTimeout=5 -vvv socks -D #{port} -N"
            output.puts ' ❌ ERROR: SSH Connection to SOCKS server unsuccessful. Error message:'
            output.puts ssh_command
            output.puts `#{ssh_command}`
          end
        end

        def configure_system_boot
          log 'Configuring SOCKS tunnel to run on system boot...' do
            install_autossh && (install_launch_agent || install_systemd_service)
          end
        end

        def launch_agent_label
          @launch_agent_label ||= begin
            launch_agent_label = 'gov.va.socks'
            launch_agent_label += "-test-#{rand 1000}" if ENV['TEST'] == 'test'
            launch_agent_label
          end
        end

        def install_autossh
          installed = !`which autossh`.empty?
          return true if installed

          if macos?
            system 'brew install autossh'
          elsif ubuntu_like?
            system 'sudo apt-get install -y autossh'
          end
        end

        def install_launch_agent
          return false unless macos?

          unless File.exist? "#{boot_script_path}/LaunchAgents/gov.va.socks.plist"
            FileUtils.mkdir_p "#{boot_script_path}/Logs/autossh"
            FileUtils.mkdir_p "#{boot_script_path}/LaunchAgents"

            write_launch_agent
          end

          system "launchctl unload #{boot_script_path}/LaunchAgents/gov.va.socks.plist 2> /dev/null"
          system "launchctl load -w #{boot_script_path}/LaunchAgents/gov.va.socks.plist"
        end

        def write_launch_agent
          erb_template = File.read File.realpath "#{__dir__}/../../templates/socks/setup/gov.va.socks.plist.erb"
          erb = ERB.new erb_template
          launch_agent_contents = erb.result(
            launch_agent_variables.instance_eval { binding }
          )
          File.write "#{boot_script_path}/LaunchAgents/gov.va.socks.plist", launch_agent_contents
        end

        def launch_agent_variables
          OpenStruct.new(
            label: launch_agent_label,
            autossh_path: `which autossh`.chomp,
            port: @port,
            boot_script_path: File.realpath(boot_script_path),
            user: ENV['USER']
          )
        end

        def install_systemd_service
          return false unless ubuntu_like?

          write_systemd_service unless File.exist? '/etc/systemd/system/va_gov_socks.service'

          system 'sudo systemctl daemon-reload'
          system 'sudo systemctl enable va_gov_socks'
          system 'sudo systemctl start va_gov_socks'
        end

        def write_systemd_service
          erb_template = File.read File.realpath "#{__dir__}/../../templates/socks/setup/va_gov_socks.service.erb"
          erb = ERB.new erb_template
          systemd_service_contents = erb.result(
            systemd_service_variables.instance_eval { binding }
          )
          File.write '/tmp/va_gov_socks.service', systemd_service_contents
          system 'sudo mv /tmp/va_gov_socks.service /etc/systemd/system/va_gov_socks.service'
        end

        def systemd_service_variables
          OpenStruct.new(
            autossh_path: `which autossh`.chomp,
            port: @port,
            ssh_key_path: ssh_key_path,
            user: ENV['USER']
          )
        end

        def configure_system_proxy
          return log 'Skipping system proxy configuration as custom --port was used.' unless port == '2001'

          if macos?
            mac_configure_system_proxy
          elsif ubuntu_like?
            ubuntu_configure_system_proxy
          end
        end

        def mac_configure_system_proxy
          return true if mac_system_proxy_already_configured?

          log 'Configuring system proxy to use SOCKS tunnel...' do
            network_interfaces.map do |network_interface|
              system %(networksetup -setautoproxyurl "#{network_interface}" "#{PROXY_URL}")
            end.all?
          end
        end

        def ubuntu_configure_system_proxy
          return true if `gsettings get org.gnome.system.proxy mode` == "'auto'\n"

          log 'Configuring system proxy to use SOCKS tunnel...' do
            `gsettings set org.gnome.system.proxy mode 'auto'` &&
              `gsettings set org.gnome.system.proxy autoconfig-url "#{PROXY_URL}"`
          end
        end

        def mac_system_proxy_already_configured?
          network_interfaces.map do |network_interface|
            output = `networksetup -getautoproxyurl "#{network_interface}"`
            output == "URL: #{PROXY_URL}\nEnabled: Yes\n"
          end.all?
        end

        def network_interfaces
          @network_interfaces ||= begin
            `networksetup -listallnetworkservices`.split("\n").drop(1).select do |network_interface|
              `networksetup -getautoproxyurl "#{network_interface}"`.start_with?('URL: (null)')
            end
          end
        end

        def test_http_connection
          output.print '----> Testing SOCKS HTTP connection...'

          success = 5.times.map do
            sleep 1
            not_connected = system "nscurl http://grafana.vfs.va.gov 2>&1 | grep -q 'hostname could not be found'"

            break [true] unless not_connected
          end.all?

          output.puts success ? ' ✅' : ' ❌ ERROR: SOCKS connection failed HTTP test. Try running setup again.'

          exit 1 unless success
        end

        def macos?
          RUBY_PLATFORM.include? 'darwin'
        end

        def ubuntu_like?
          return false if `which apt-get`.empty? && `which gsettings`.empty?

          true
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
          if block_given?
            output.print "----> #{message}"

            return_value = yield

            output.puts return_value ? ' ✅' : ' ❌'

            return_value
          else
            output.puts "----> #{message}"
          end
        end
      end
    end
  end
end
