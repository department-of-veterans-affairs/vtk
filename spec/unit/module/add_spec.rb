# frozen_string_literal: true

require 'vtk/commands/module/add'

RSpec.describe Vtk::Commands::Module::Add do
  it 'executes `module add` command successfully' do
    output = StringIO.new
    name = nil
    options = {}
    command = Vtk::Commands::Module::Add.new(name, options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
