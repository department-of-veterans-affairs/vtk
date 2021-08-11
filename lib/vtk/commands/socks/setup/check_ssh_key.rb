# frozen_string_literal: true

module Vtk
  module Commands
    class Socks
      class Setup
        # Checks the VA SSH key exists, matches the public key, and if not, guides user to create it
        module CheckSshKey
          def check_ssh_key
            return true if key_exists? && private_and_public_keys_match?

            @ssh_key_created = generate_key_and_open_key_access_request
          end

          def key_exists?
            File.exist? ssh_key_path
          end

          def private_and_public_keys_match?
            return true unless public_key_exists?

            pub_key_from_private = `ssh-keygen -y -e -f #{ssh_key_path}`
            pub_key_from_public = `ssh-keygen -y -e -f #{ssh_key_path}.pub`
            return true if pub_key_from_private == pub_key_from_public

            log "❌ ERROR: #{ssh_key_path}.pub is not the public key for #{ssh_key_path}."
            exit 1
          end

          def public_key_exists?
            File.exist? "#{ssh_key_path}.pub"
          end

          def generate_key_and_open_key_access_request
            log 'VA key missing. Generating now...'
            system "ssh-keygen -f #{ssh_key_path} #{'-N ""' if ENV['TEST']}"

            if prompt.yes?(copy_and_open_gh)
              copy_key_to_clipboard
              open_command ACCESS_REQUEST_TEMPLATE_URL
            else
              key_contents = File.read "#{ssh_key_path}.pub"
              log "Copy this key & submit in the access request form (#{ACCESS_REQUEST_TEMPLATE_URL}):\n" + key_contents
            end
          end

          def copy_key_to_clipboard
            ssh_key_contents = File.read "#{ssh_key_path}.pub"

            if copy_command
              IO.popen(copy_command, 'w') { |f| f << ssh_key_contents }
            elsif wsl?
              system %(powershell.exe Set-Clipboard -Value "'#{ssh_key_contents}'")
            end
          end

          def copy_and_open_gh
            '----> An SSH key has been created. Would you like to copy the key to your clipboard and open the access ' \
              'request issue in GitHub now?'
          end
        end
      end
    end
  end
end
