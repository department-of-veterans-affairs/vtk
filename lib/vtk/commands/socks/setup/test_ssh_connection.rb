# frozen_string_literal: true

module Vtk
  module Commands
    class Socks
      class Setup
        # Tests SSH connection to jumpbox and accepts first-time host authenticity (ignoring if entry exists)
        module TestSshConnection
          def test_ssh_connection
            output.print '----> Testing SOCKS SSH connection...'

            add_ip_to_known_hosts

            if proxy_running? || ssh_output.include?('This account is currently not available.')
              output.puts ' ✅ DONE'
            else
              check_ssh_error ssh_output
              exit 1
            end
          end

          def ssh_output
            `ssh -i #{ssh_key_path} -F #{ssh_config_path} -o ConnectTimeout=5 -q socks -D #{port} exit 2>&1`
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
              output.puts '⚠️  WARN: SSH key is not approved yet. Once it is, re-run `vtk socks setup`.'
              copy_key_to_clipboard if prompt.yes? 'Would you like to copy your VA public key to your clipboard again?'
            else
              ssh_command = "ssh -i #{ssh_key_path} -F #{ssh_config_path} -o ConnectTimeout=5 -vvv socks -D #{port} -N"
              output.puts ' ❌ ERROR: SSH Connection to SOCKS server unsuccessful. Error message:'
              output.puts ssh_command
              output.puts `#{ssh_command}`
            end
          end
        end
      end
    end
  end
end
