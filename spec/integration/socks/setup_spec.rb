# frozen_string_literal: true

require 'open3'

RSpec.describe '`vtk socks setup` command', type: :cli do
  it 'executes `vtk socks help setup` command successfully' do
    output = `vtk socks help setup`
    expected_output = <<~OUT
      Usage:
        vtk socks setup

      Options:
        -h, [--help], [--no-help]                  # Display usage information
            [--boot-script-path=BOOT_SCRIPT_PATH]  # Path to install boot script (e.g. ~/Library)
            [--ssh-key-path=SSH_KEY_PATH]          # Path to SSH key (e.g. ~/.ssh/id_rsa_vagov)
            [--ssh-config-path=SSH_CONFIG_PATH]    # Path to SSH config (e.g. ~/.ssh/config)
        -p, [--port=PORT]                          # Port that SOCKS server is running on
            [--skip-test], [--no-skip-test]        # Skip testing SOCKS connection

      Configures local machine for VA SOCKS access
    OUT

    expect(output).to eq(expected_output)
  end

  context 'executes `socks setup` commands successfully' do
    def parse_lines(output)
      output.gsub("\e[1A", '').split("\e[2K\e[1G").map { |line| line.split "\n" }.flatten.uniq
    end

    def run_and_answer(command, answers)
      Open3.popen2e(command) do |stdin, stdout_stderr, _wait_thread|
        thread = Thread.new { Thread.current[:output] = stdout_stderr }

        answers.each { |answer| stdin.puts answer }
        stdin.close

        thread.join
        return parse_lines thread[:output].read
      end
    end

    before do
      `mkdir -p tmp/ssh`
      unset_proxy_url unless ENV['CI']
    end

    after do
      `rm -rf tmp/ssh`
      set_proxy_url_back unless ENV['CI']
    end

    def unset_proxy_url
      save_starting_proxy_url
      `networksetup -setautoproxyurl "#{@network_interface}" "(null)"`
    end

    def save_starting_proxy_url
      @network_interface = `networksetup -listallnetworkservices`.split("\n").drop(1).pop
      @starting_proxy_url = `networksetup -getautoproxyurl "#{@network_interface}"`.split("\n")[0].split[1]
    end

    def set_proxy_url_back
      `networksetup -setautoproxyurl "#{@network_interface}" "#{@starting_proxy_url}"`
    end

    it 'requires an ssh key to already be configured' do
      skip 'CI environment does not have SOCKS access' if ENV['CI']

      cmd = 'vtk socks setup --ssh-config-path tmp/ssh/config --ssh-key-path tmp/ssh/key'
      output = run_and_answer cmd, []

      expect(output[0]).to eq(
        "----> Please create an SSH key using `ssh-keygen -f ~/.ssh/id_rsa_vagov`. You'll have to wait for access " \
        'approval before continuing. Once approved, re-run `vtk socks setup`.'
      )
      expect(output[1]).to eq('Open access request form in GitHub? (Y/n) ')
      expect(output[2]).to eq('Open access request form in GitHub? Yes')
    end

    it 'succesfully sets everything up' do
      skip 'CI environment does not have SOCKS access' if ENV['CI']

      `cp ~/.ssh/id_rsa_vagov tmp/ssh/key`
      cmd = 'vtk socks setup --ssh-config-path tmp/ssh/config --ssh-key-path tmp/ssh/key ' \
        '--boot-script-path tmp/ssh'
      output = run_and_answer cmd, []

      `launchctl unload -w tmp/ssh/LaunchAgents/gov.va.socks.plist`

      expect(output[0]).to eq('----> Installing SSH config...')
      expect(output[1]).to eq('----> Testing SOCKS SSH connection... ✅')
      expect(output[2]).to eq('----> Configuring SOCKS tunnel to run on system boot... ✅')
      expect(output[3]).to eq('----> Configuring system proxy to use SOCKS tunnel... ✅')
      expect(output[4]).to eq('----> Testing SOCKS HTTP connection... ✅')
      expect(output[5]).to eq('----> SOCKS setup complete.')
    end
  end
end
