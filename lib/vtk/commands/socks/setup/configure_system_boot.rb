# frozen_string_literal: true

module Vtk
  module Commands
    class Socks
      class Setup
        # Ensures VA Proxy starts on system boot
        module ConfigureSystemBoot
          def configure_system_boot
            log 'Configuring SOCKS tunnel to run on system boot...' do
              if wsl?
                wsl_configure_system_boot && wsl_start_socks_proxy
              else
                install_autossh && (install_launch_agent || install_systemd_service)
              end
            end
          end

          def wsl_configure_system_boot
            return true if File.exist? socks_bat

            IO.write socks_bat, 'wsl nohup bash -c "/usr/bin/ssh socks -N &" < nul > nul 2>&1', mode: 'a'
          end

          def socks_bat
            "#{socks_bat_dir}/gov.va.socks.bat"
          end

          def socks_bat_dir
            profile_path = `wslpath "$(wslvar USERPROFILE)"`.chomp
            "#{profile_path}/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"
          end

          def wsl_start_socks_proxy
            return true if proxy_running?

            system "cd '#{socks_bat_dir}'; cmd.exe /c gov.va.socks.bat > /dev/null"
          end

          def proxy_running?
            system("lsof -i:#{port}", out: '/dev/null') || system('lsof -nP | grep ssh | grep -q sock')
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
              FileUtils.mkdir_p "#{boot_script_path}/Logs/gov.va.socks"
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
        end
      end
    end
  end
end
