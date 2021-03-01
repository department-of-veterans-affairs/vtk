# frozen_string_literal: true

require 'vtk/commands/module/service'

RSpec.describe Vtk::Commands::Module::Service do
  it 'executes `module service` command successfully' do
    output = StringIO.new
    name = 'bar'
    options = { module_name: 'foo' }
    command = Vtk::Commands::Module::Service.new(name, options)

    allow(command).to receive :create_service
    expect(command).to receive(:create_service).with 'bar', { module_name: 'foo' }

    command.execute _output: output
  end

  it 'fails `module service` command when module_name is not included' do
    output = "No value provided for required options '--module-name'"
    name = 'bar'
    options = {}
    command = Vtk::Commands::Module::Service.new(name, options)

    allow(command).to receive :create_service
    expect(command).to receive(:create_service).with('bar', {}).and_return(output)

    command.execute
  end
end
