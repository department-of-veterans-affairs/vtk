# frozen_string_literal: true

module Vtk
  module Commands
    class Socks
      class Setup
        # Sets proxy.pac for system-wide SOCKS proxy (only redirecting relevant domains through proxy)
        module ConfigureSystemProxy
          def configure_system_proxy
            return log 'Skipping system proxy configuration as custom --port was used.' unless port == '2001'

            if macos?
              mac_configure_system_proxy
            elsif wsl?
              wsl_configure_system_proxy
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

          def wsl_configure_system_proxy
            log 'Configuring system proxy to use SOCKS tunnel...' do
              reg_key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
              `powershell.exe Set-ItemProperty -path "'#{reg_key}'" AutoConfigURL -Value "'#{PROXY_URL}'"`
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
        end
      end
    end
  end
end
