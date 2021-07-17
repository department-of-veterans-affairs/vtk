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

          check_ssh_key
          configure_ssh
          test_ssh_connection unless skip_test

          configure_system_boot
          configure_system_proxy

          test_http_connection unless skip_test

          log 'SOCKS setup complete.'
        end

        private

        def check_ssh_key
          return true if key_exists?

          open_key_access_request
          exit
        end

        def key_exists?
          File.exist? ssh_key_path
        end

        def open_key_access_request
          url = 'https://github.com/department-of-veterans-affairs/va.gov-team/issues/new?' \
            'assignees=&labels=external-request%2C+operations&template=Environment-Access-Request-Template.md&' \
            'title=Access+for+%5Bindividual%5D'
          log "Please create an SSH key using `ssh-keygen -f ~/.ssh/id_rsa_vagov`. You'll have to wait for access " \
            'approval before continuing. Once approved, re-run `vtk socks setup`.'
          `#{macos? ? 'open' : 'xdg-open'} "#{url}"` if prompt.yes? 'Open access request form in GitHub?'
        end

        def configure_ssh
          install_ssh_config
          configure_ssh_config_with_keychain
          ssh_config_clean_up
          ssh_agent_add
        end

        def install_ssh_config
          return true if ssh_config_configured?

          if ssh_config_exists? && !prompt.yes?("----> #{pretty_ssh_config_path} incomplete. Backup and replace now?")
            return false
          end

          log 'Installing SSH config...'

          download_ssh_config unless File.exist? '/tmp/dova-devops'
          create_ssh_directory
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
          install_brew

          ssh_config_clean_up

          repo_url = 'https://github.com/department-of-veterans-affairs/devops.git'
          cloned = system(
            "git clone --quiet#{' --depth 1' if macos?} --no-checkout --filter=blob:none #{repo_url} '/tmp/dova-devops'"
          )
          exit 1 unless cloned

          `cd /tmp/dova-devops; git checkout master -- ssh/config`
        end

        def install_brew
          return false unless macos?

          installed = !`command -v brew`.empty?
          return true if installed

          log 'Homebrew not installed. Please install and try again.'
          `open "https://brew.sh"` if prompt.yes? 'Open https://brew.sh for installation instructions?'
          exit 1
        end

        def ssh_config_clean_up
          FileUtils.rm_rf '/tmp/dova-devops'
        end

        def backup_existing_ssh_config
          return true unless File.exist? ssh_config_path

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
          if macos?
            `ssh-add -K 2> /dev/null; ssh-add -K #{ssh_key_path} 2> /dev/null`
          elsif ubuntu?
            `[ -z "$SSH_AUTH_SOCK" ] && eval "$(ssh-agent -s)";
              ssh-add 2> /dev/null; ssh-add #{ssh_key_path} 2> /dev/null`
          end
        end

        def test_ssh_connection
          output.print '----> Testing SOCKS SSH connection...'

          add_ip_to_known_hosts

          ssh_output = `ssh -F #{ssh_config_path} -o ConnectTimeout=5 -q socks -D #{port} exit`.chomp
          if ssh_output == 'This account is currently not available.'
            output.puts ' ✅'
          else
            output.puts ' ❌ ERROR: SSH Connection to SOCKS server unsuccessful. Error message:'
            output.puts `ssh -F #{ssh_config_path} -o ConnectTimeout=5 -vvv socks -D #{port} -N`
            exit 1
          end
        end

        def add_ip_to_known_hosts
          jump_box_ip = `grep -A 2 'Host socks' ~/.ssh/config | grep ProxyCommand | awk '{print $6}'`.chomp
          socks_ip = `grep -A 2 'Host socks' ~/.ssh/config | grep HostName | awk '{print $2}'`.chomp

          `ssh-keygen -R #{jump_box_ip}` if File.exist? '~/.ssh/known_hosts'
          `ssh-keygen -R #{socks_ip}` if File.exist? '~/.ssh/known_hosts'
          `ssh-keyscan -H #{jump_box_ip} >> ~/.ssh/known_hosts 2> /dev/null`
          `ssh -i #{ssh_key_path} dsva@#{jump_box_ip} 'ssh-keyscan -H #{socks_ip}' >> ~/.ssh/known_hosts 2> /dev/null`
        end

        def configure_system_boot
          return false unless macos?
          return true unless `launchctl list | grep #{launch_agent_label}`.empty?

          log 'Configuring SOCKS tunnel to run on system boot...' do
            install_autossh
            install_launch_agent
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
          installed = !`command -v autossh`.empty?
          return true if installed

          log '----> Autossh missing. Installing via Homebrew.'

          `brew install autossh`
        end

        def install_launch_agent
          unless File.exist? "#{boot_script_path}/LaunchAgents/gov.va.socks.plist"
            FileUtils.mkdir_p "#{boot_script_path}/Logs/autossh"
            FileUtils.mkdir_p "#{boot_script_path}/LaunchAgents"

            write_launch_agent
          end

          `launchctl load -w #{boot_script_path}/LaunchAgents/gov.va.socks.plist`
        end

        def write_launch_agent
          erb_template = File.read "#{__dir__}/gov.va.socks.plist.erb"
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

        def configure_system_proxy
          return false unless macos?
          return log 'Skipping system proxy configuration as custom --port was used.' unless port == '2001'
          return true if system_proxy_already_configured?

          log 'Configuring system proxy to use SOCKS tunnel...' do
            network_interfaces.map do |network_interface|
              system %(networksetup -setautoproxyurl "#{network_interface}" "#{PROXY_URL}")
            end.all?
          end
        end

        def system_proxy_already_configured?
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

          output.puts success ? ' ✅' : ' ❌ ERROR: SOCKS connection failed HTTP test.'

          exit 1 unless success
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
