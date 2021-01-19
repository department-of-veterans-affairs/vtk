# frozen_string_literal: true

RSpec.describe '`vtk module model` command', type: :cli do
  it 'executes `vtk module help model` command successfully' do
    output = `vtk module help model`
    expected_output = <<~OUT
      Usage:
        vtk module model <module name>

      Options:
        -h, [--help], [--no-help]  # Display usage information

      Add new model to a module in vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
