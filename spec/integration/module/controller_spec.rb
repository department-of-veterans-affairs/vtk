# frozen_string_literal: true

RSpec.describe '`vtk module controller` command', type: :cli do
  it 'executes `vtk module help controller` command successfully' do
    output = `vtk module help controller`
    expected_output = <<~OUT
      Usage:
        vtk module controller <component name> -m, --module-name=MODULE_NAME

      Options:
        -h, [--help], [--no-help], [--skip-help]  # Display usage information
        -m, --module-name=MODULE_NAME             # Specify the module name

      Add new controller to a module in vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
