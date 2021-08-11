# frozen_string_literal: true

module Vtk
  module Commands
    class Socks
      class Setup
        # Ensures latest .ssh/config is downloaded from the devops repo
        module SetupSshConfig
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
            system 'git config --global credential.helper > /dev/null || ' \
              "git config --global credential.helper 'cache --timeout=600'"
            cloned = system(
              "git clone -q#{' --depth 1' if macos?} --no-checkout --filter=blob:none #{repo_url} '/tmp/dova-devops'"
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
        end
      end
    end
  end
end
