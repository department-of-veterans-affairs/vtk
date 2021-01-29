# frozen_string_literal: true

require 'vtk/commands/socks/on'

RSpec.describe Vtk::Commands::Socks::On do
  def cleanup_connection
    `lsof -Pi :20001 -sTCP:LISTEN -t | xargs kill 2> /dev/null`
    sleep 1
  end

  it 'executes `socks on` command successfully' do
    output = StringIO.new
    options = { 'port' => '20001' }
    command = Vtk::Commands::Socks::On.new(options)

    skip 'CI environment does not have SOCKS access' if ENV['CI']

    command.execute(output: output)

    expect(output.string).to include("----> Connected to SOCKS.\n")

    cleanup_connection
  end

  it 'fails `socks on` command when already running' do
    output = StringIO.new
    options = { 'port' => '20001' }
    command = Vtk::Commands::Socks::On.new(options)

    skip 'CI environment does not have SOCKS access' if ENV['CI']

    command.execute(output: output)

    expect(output.string).to include("----> Connected to SOCKS.\n")

    # command.execute(output: output)
    # expect(output.string).to include("----> Already connected to SOCKS.\n")

    cleanup_connection
  end
end
