# frozen_string_literal: true

RSpec.describe '`vtk module model` command', type: :cli do
  it 'executes `vtk module help model` command successfully' do
    output = `vtk module help model`
    expected_output = <<~OUT
      Usage:
        vtk module model <component name> -m, --module-name=MODULE_NAME

      Options:
        -h, [--help], [--no-help]      # Display usage information
        -m, --module-name=MODULE_NAME  # Specify the module name

      Add new model to a module in vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
