# frozen_string_literal: true

RSpec.describe '`vtk module` command', type: :cli do
  it 'executes `vtk help module` successfully and contains add command' do
    output = `vtk help module`
    expected_output = <<~OUT
      vtk module add <module name>         # Add a new module to vets-api
    OUT
    expect(output).to include(expected_output)
  end

  it 'executes `vtk help module` successfully and contains add command' do
    output = `vtk help module`
    expected_output = "  vtk module controller <module name>  # Add new controller to a module in vets-api"
    expect(output).to include(expected_output)
  end

  it 'executes `vtk help module` successfully and contains model command' do
    output = `vtk help module`
    expected_output = <<~OUT
      vtk module model <module name>       # Add new model to a module in vets-api
    OUT
    expect(output).to include(expected_output)
  end
end
