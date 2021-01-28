require 'vtk/commands/socks/off'

RSpec.describe Vtk::Commands::Socks::Off do
  it "executes `socks off` command successfully" do
    output = StringIO.new
    options = {}
    command = Vtk::Commands::Socks::Off.new(options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
