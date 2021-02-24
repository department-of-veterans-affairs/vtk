# frozen_string_literal: true

RSpec.describe '`vtk module` command', type: :cli do
  it 'executes `vtk module help` successfully and contains add command' do
    output = `vtk module help add`
    expect(output).to include('vtk module add')
    expect(output).to include('Add a new module')
  end

  it 'executes `vtk module help` successfully and contains controller command' do
    output = `vtk module help controller`
    expect(output).to include('vtk module controller')
    expect(output).to include('Add new controller')
  end

  it 'executes `vtk module help` successfully and contains model command' do
    output = `vtk module help model`
    expect(output).to include('vtk module model')
    expect(output).to include('Add new model')
  end

  it 'executes `vtk module help` successfully and contains serializer command' do
    output = `vtk module help serializer`
    expect(output).to include('vtk module serializer')
    expect(output).to include('Add new serializer')
  end

  it 'executes `vtk module help` successfully and contains service command' do
    output = `vtk module help service`
    expect(output).to include('vtk module service')
    expect(output).to include('Add new service')
  end
end
