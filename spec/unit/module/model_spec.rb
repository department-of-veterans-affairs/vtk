# frozen_string_literal: true

require 'vtk/commands/module/model'

RSpec.describe Vtk::Commands::Module::Model do
  it 'executes `module model` command successfully' do
    output = StringIO.new
    name = 'foo'
    options = {}
    command = Vtk::Commands::Module::Model.new(name, options)

    allow(command).to receive :create_model
    expect(command).to receive(:create_model).with 'foo', {}

    command.execute _output: output
  end
end
