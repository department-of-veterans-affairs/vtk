# frozen_string_literal: true

RSpec.describe '`vtk module controller` command', type: :cli do
  it 'executes `vtk module help controller` command successfully' do
    output = `vtk module help controller`
    expected_output = <<~OUT
      Usage:
        vtk module controller <module name>

      Options:
        -h, [--help], [--no-help]              # Display usage information
        -n, [--component-name=COMPONENT_NAME]  # Specify the controller name

      Add new controller to a module in vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
