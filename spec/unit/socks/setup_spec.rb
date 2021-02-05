# frozen_string_literal: true

require 'vtk/commands/socks/setup'

RSpec.describe Vtk::Commands::Socks::Setup do
  it 'executes `socks setup` command successfully' do
    output = StringIO.new
    options = {}
    command = Vtk::Commands::Socks::Setup.new(options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
