# frozen_string_literal: true

RSpec.describe '`vtk module` command', type: :cli do
  it 'executes `vtk help module` successfully and contains add command' do
    output = `vtk help module`
    expect(output).to include('vtk module add')
    expect(output).to include('# Add a new module')
  end

  it 'executes `vtk help module` successfully and contains controller command' do
    output = `vtk help module`
    expect(output).to include('vtk module controller')
    expect(output).to include('# Add new controller')
  end

  it 'executes `vtk help module` successfully and contains model command' do
    output = `vtk help module`
    expect(output).to include('vtk module model')
    expect(output).to include('# Add new model')
  end

  it 'executes `vtk help module` successfully and contains serializer command' do
    output = `vtk help module`
    expect(output).to include('vtk module serializer')
    expect(output).to include('# Add new serializer')
  end

  it 'executes `vtk help module` successfully and contains service command' do
    output = `vtk help module`
    expect(output).to include('vtk module service')
    expect(output).to include('# Add new service')
  end
end
