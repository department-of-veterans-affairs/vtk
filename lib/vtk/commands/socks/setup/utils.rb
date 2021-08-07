# frozen_string_literal: true

module Vtk
  module Commands
    class Socks
      class Setup
        # General Utils class for socks setup
        module Utils
          def copy_command
            if macos?
              'pbcopy'
            elsif ubuntu_like? && !wsl?
              system 'sudo apt-get install -y xsel' if `which xsel`.empty?
              'xsel --clipboard'
            end
          end

          def open_command(url)
            if macos?
              `open "#{url}"`
            elsif wsl?
              `powershell.exe Start '"#{url}"'`
            elsif ubuntu_like?
              `xdg-open "#{url}"`
            end
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

          def macos?
            RUBY_PLATFORM.include? 'darwin'
          end

          def ubuntu_like?
            return false if `which apt-get`.empty? && `which gsettings`.empty?

            true
          end

          def wsl?
            @wsl ||= File.exist?('/proc/version') && File.open('/proc/version').grep(/Microsoft/).size.positive?
          end

          def log(message)
            if block_given?
              output.print "----> #{message}"

              return_value = yield

              output.puts return_value ? ' ✅ DONE' : ' ❌ FAIL'

              return_value
            else
              output.puts "----> #{message}"
            end
          end
        end
      end
    end
  end
end
