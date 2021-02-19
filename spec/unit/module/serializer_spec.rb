# frozen_string_literal: true

require 'vtk/commands/module/serializer'

RSpec.describe Vtk::Commands::Module::Serializer do
  it 'executes `module serializer` command successfully' do
    output = StringIO.new
    name = 'foo'
    options = {}
    command = Vtk::Commands::Module::Serializer.new(name, options)

    allow(command).to receive :create_serializer
    expect(command).to receive(:create_serializer).with 'foo', {}

    command.execute _output: output
  end
end
