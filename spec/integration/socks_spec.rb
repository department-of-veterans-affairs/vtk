# frozen_string_literal: true

RSpec.describe '`vtk socks` command', type: :cli do
  it 'executes `vtk help socks` command successfully' do
    output = `vtk help socks`
    expected_output = <<~OUT
      Commands:
        vtk socks help [COMMAND]  # Describe subcommands or one specific subcommand
        vtk socks off             # Disconnects from VA SOCKS
        vtk socks on              # Connects to VA SOCKS
        vtk socks setup           # Configures local machine for VA SOCKS access
        vtk socks tree            # Print a tree of all available commands

    OUT

    expect(output).to eq(expected_output)
  end
end
