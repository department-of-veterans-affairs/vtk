# frozen_string_literal: true

RSpec.describe '`vtk module` command', type: :cli do
  it 'executes `vtk help module` command successfully' do
    output = `vtk help module`
    expected_output = <<~OUT
      Commands:
        vtk module add <module name>  # Add a new module to vets-api
        vtk module help [COMMAND]     # Describe subcommands or one specific subcommand

    OUT

    expect(output).to eq(expected_output)
  end
end
