# frozen_string_literal: true

require 'vtk/commands/module/service'

RSpec.describe Vtk::Commands::Module::Service do
  it 'executes `module service` command successfully' do
    output = StringIO.new
    name = 'foo'
    options = {}
    command = Vtk::Commands::Module::Service.new(name, options)

    allow(command).to receive :create_service
    expect(command).to receive(:create_service).with 'foo', {}

    command.execute _output: output
  end
end
