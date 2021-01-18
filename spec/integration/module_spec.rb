# frozen_string_literal: true

RSpec.describe '`vtk module` command', type: :cli do
  it 'executes `vtk help module` successfully and contains add command' do
    output = `vtk help module`
    expected_output = <<~OUT
      vtk module add <module name>         # Add a new module to vets-api
    OUT
    expect(output).to include(expected_output)
  end

  it 'executes `vtk help module` successfully and contains controller command' do
    output = `vtk help module`
    expect(output).to include('vtk module controller <module name>')
    expect(output).to include('# Add new controller')
  end

  it 'executes `vtk help module` successfully and contains model command' do
    output = `vtk help module`
    expected_output = <<~OUT
      vtk module model <module name>       # Add new model to a module in vets-api
    OUT
    expect(output).to include(expected_output)
  end

  it 'executes `vtk help module` successfully and contains serializer command' do
    output = `vtk help module`
    expect(output).to include('vtk module serializer <module name>')
  end

  it 'executes `vtk help module` successfully and contains service command' do
    output = `vtk help module`
    expect(output).to include('vtk module service <module name>')
  end
end
