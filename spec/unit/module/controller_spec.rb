# frozen_string_literal: true

require 'vtk/commands/module/controller'

RSpec.describe Vtk::Commands::Module::Controller do
  it 'executes `module controller` command successfully' do
    output = StringIO.new
    name = 'foo'
    options = {}
    command = Vtk::Commands::Module::Controller.new(name, options)

    allow(command).to receive :create_controller
    expect(command).to receive(:create_controller).with 'foo', {}

    command.execute _output: output
  end
end
