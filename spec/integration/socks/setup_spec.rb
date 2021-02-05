# frozen_string_literal: true

require 'open3'

RSpec.describe '`vtk socks setup` command', type: :cli do
  it 'executes `vtk socks help setup` command successfully' do
    output = `vtk socks help setup`
    expected_output = <<~OUT
      Usage:
        vtk socks setup

      Options:
        -h, [--help], [--no-help]                # Display usage information
            [--ssh-key-path=SSH_KEY_PATH]        # Path to SSH key (e.g. ~/.ssh/id_rsa_vagov)
            [--ssh-config-path=SSH_CONFIG_PATH]  # Path to SSH config (e.g. ~/.ssh/config)
        -p, [--port=PORT]                        # Port that SOCKS server is running on

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

    after do
      `rm -rf tmp/ssh`
    end

    it 'succesfully says no to every answer' do
      skip 'CI environment does not have SOCKS access' if ENV['CI']

      cmd = 'vtk socks setup --ssh-config-path tmp/ssh/config --ssh-key-path tmp/ssh/key --port 20002'
      output = run_and_answer cmd, [
        'n', # Create SSH Key?
        'n', # Install ssh/config?
        'n', # Install keychain config?
        'n'  # Test SOCKS connectin?
      ]

      expect(output[2]).to eq('----> SSH Key not found. Create one now? no')
      expect(output[5]).to eq('----> tmp/ssh/config missing or incomplete. Install/replace now? no')
      expect(output[8]).to eq('----> tmp/ssh/config missing Keychain configuration. Add now? no')
      expect(output[11]).to eq('----> Test SOCKS connection now? no')
      expect(output[12]).to eq('----> SOCKS has been setup. Run `vtk socks on` to turn on.')
    end

    it 'succesfully says yes to every answer' do
      skip 'CI environment does not have SOCKS access' if ENV['CI']

      cmd = 'vtk socks setup --ssh-config-path tmp/ssh/config --ssh-key-path tmp/ssh/key --port 20002'
      output = run_and_answer cmd, [
        'n', # Create SSH Key?
        '',  # No pass phrase for key
        '',  # No pass phrase for key confirmation
        'n', # Install ssh/config?
        'n', # Install keychain config?
        'n'  # Test SOCKS connectin?
      ]

      expect(output[2]).to eq('----> SSH Key not found. Create one now? no')
      expect(output[5]).to eq('----> tmp/ssh/config missing or incomplete. Install/replace now? no')
      expect(output[8]).to eq('----> tmp/ssh/config missing Keychain configuration. Add now? no')
      expect(output[11]).to eq('----> Test SOCKS connection now? no')
      expect(output[12]).to eq('----> SOCKS has been setup. Run `vtk socks on` to turn on.')
    end

    it 'executes `socks setup` command successfully' do
      skip 'CI environment does not have SOCKS access' if ENV['CI']

      cmd = 'vtk socks setup --ssh-config-path tmp/ssh/config --ssh-key-path tmp/ssh/key --port 20002'
      output = run_and_answer cmd, [
        'n', # Create SSH Key?
        'y', # Install ssh/config?
        'n', # Install keychain config?
        'n'  # Test SOCKS connectin?
      ]

      expect(output[5]).to eq('----> tmp/ssh/config missing or incomplete. Install/replace now? Yes')
      expect(output[6]).to eq('----> Downloading ssh/config.')
      expect(File.read('tmp/ssh/config')).to include('Host socks')
    end
  end
end
