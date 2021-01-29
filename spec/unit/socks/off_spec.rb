# frozen_string_literal: true

require 'vtk/commands/socks/off'
require 'socket'

RSpec.describe Vtk::Commands::Socks::Off do
  def start_listener
    Process.fork do
      TCPServer.new 20_000
      sleep 300
    end
  end

  def listener_running?
    `lsof -Pi :20000 -sTCP:LISTEN -t` != ''
  end

  it 'executes `socks off` command successfully' do
    expect(listener_running?).to be false

    output = StringIO.new
    options = { 'port' => '20000' }
    command = Vtk::Commands::Socks::Off.new options

    start_listener
    expect(listener_running?).to be true

    command.execute(output: output)

    expect(output.string).to eq("----> Disconnected from SOCKS.\n")
    expect(listener_running?).to be false
  end

  it 'fails `socks off` command when no process running' do
    expect(listener_running?).to be false

    output = StringIO.new
    options = { 'port' => '20000' }
    command = Vtk::Commands::Socks::Off.new options

    command.execute(output: output)

    expect(output.string).to eq("----> No SOCKS connection found.\n")
  end
end
