# frozen_string_literal: true

require 'vtk/commands/module/add'

RSpec.describe Vtk::Commands::Module::Add do
  it 'executes `module add` command successfully' do
    output = StringIO.new
    name = 'foo'
    options = {}
    command = Vtk::Commands::Module::Add.new(name, options)

    allow(command).to receive :create_module
    expect(command).to receive(:create_module).with 'foo'

    command.execute _output: output
  end
end
