# frozen_string_literal: true

RSpec.describe '`vtk module add` command', type: :cli do
  it 'executes `vtk module help add` command successfully' do
    output = `vtk module help add`
    expected_output = <<~OUT
      Usage:
        vtk module add NAME

      Options:
        -h, [--help], [--no-help]  # Display usage information

      Command description...
    OUT

    expect(output).to eq(expected_output)
  end
end
