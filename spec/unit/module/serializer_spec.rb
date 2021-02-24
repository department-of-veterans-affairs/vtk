# frozen_string_literal: true

require 'vtk/commands/module/serializer'

RSpec.describe Vtk::Commands::Module::Serializer do
  it 'executes `module serializer` command successfully' do
    output = StringIO.new
    name = 'bar'
    options = { module_name: 'foo' }
    command = Vtk::Commands::Module::Serializer.new(name, options)

    allow(command).to receive :create_serializer
    expect(command).to receive(:create_serializer).with 'bar', { module_name: 'foo' }

    command.execute _output: output
  end
end
