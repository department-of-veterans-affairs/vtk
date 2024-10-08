# frozen_string_literal: true

RSpec.describe '`vtk module add` command', type: :cli do
  it 'executes `vtk module help add` command successfully' do
    output = `vtk module help add`
    expected_output = <<~OUT
      Usage:
        vtk module add <module name>

      Options:
        -h, [--help], [--no-help], [--skip-help]  # Display usage information

      Add a new module to vets-api
    OUT

    expect(output).to eq(expected_output)
  end
end
