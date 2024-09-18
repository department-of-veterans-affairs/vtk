# frozen_string_literal: true

require 'socket'

RSpec.describe '`vtk socks off` command', type: :cli do
  def start_listener
    Process.fork do
      TCPServer.new 20_000
      sleep 300
    end
  end

  def listener_running?
    `lsof -Pi :20000 -sTCP:LISTEN -t` != ''
  end

  it 'executes `vtk socks help off` command successfully' do
    output = `vtk socks help off`
    expected_output = <<~OUT
      Usage:
        vtk socks off

      Options:
        -h, [--help], [--no-help], [--skip-help]  # Display usage information
        -p, [--port=PORT]                         # Port that SOCKS server is running on

      Disconnects from VA SOCKS
    OUT

    expect(output).to eq(expected_output)
  end

  it 'executes `socks off` command successfully' do
    expect(listener_running?).to be false
    start_listener
    expect(listener_running?).to be true

    output = `vtk socks off --port 20000`

    expect(output).to eq("----> Disconnected from SOCKS.\n")
    expect(listener_running?).to be false
  end

  it 'fails `socks off` command when no process running' do
    expect(listener_running?).to be false

    output = `vtk socks off --port 20000`

    expect(output).to eq("----> No SOCKS connection found.\n")
  end
end
