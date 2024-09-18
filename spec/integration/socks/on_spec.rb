# frozen_string_literal: true

RSpec.describe '`vtk socks on` command', type: :cli do
  after do
    cleanup_connection
  end

  def cleanup_connection
    `lsof -Pi :20001 -sTCP:LISTEN -t | xargs kill 2> /dev/null`
    sleep 0.1 until `lsof -Pi :20001 -sTCP:LISTEN -t` == ''
  end

  it 'executes `vtk socks help on` command successfully' do
    output = `vtk socks help on`
    expected_output = <<~OUT
      Usage:
        vtk socks on

      Options:
        -h, [--help], [--no-help], [--skip-help]  # Display usage information
        -p, [--port=PORT]                         # Port to run SOCKS server on

      Connects to VA SOCKS
    OUT

    expect(output).to eq(expected_output)
  end

  it 'executes `socks on` command successfully' do
    skip 'CI environment does not have SOCKS access' if ENV['CI']

    output = `vtk socks on --port 20001`

    expect(output).to include("----> Connected to SOCKS.\n")
  end

  it 'fails `socks on` command when already running' do
    skip 'CI environment does not have SOCKS access' if ENV['CI']

    output = `vtk socks on --port 20001`
    expect(output).to include("----> Connected to SOCKS.\n")

    output = `vtk socks on --port 20001`
    expect(output).to include("----> Already connected to SOCKS.\n")
  end
end
