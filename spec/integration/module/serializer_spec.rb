# frozen_string_literal: true

RSpec.describe '`vtk module serializer` command', type: :cli do
  it 'executes `vtk module help serializer` command successfully' do
    output = `vtk module help serializer`
    expected_output = <<~OUT
      Usage:
        vtk module serializer <module name>

      Options:
        -h, [--help], [--no-help]              # Display usage information
        -n, [--component-name=COMPONENT_NAME]  # Specify the serializer name

      Add new serializer to a module in vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
