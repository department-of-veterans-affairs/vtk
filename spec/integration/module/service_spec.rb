# frozen_string_literal: true

RSpec.describe '`vtk module service` command', type: :cli do
  it 'executes `vtk module help service` command successfully' do
    output = `vtk module help service`
    expected_output = <<~OUT
      Usage:
        vtk module service <component name> -m, --module-name=MODULE_NAME

      Options:
        -h, [--help], [--no-help]      # Display usage information
        -m, --module-name=MODULE_NAME  # Specify the module name

      Add new service class to a module in vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
