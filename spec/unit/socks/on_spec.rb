require 'vtk/commands/socks/on'

RSpec.describe Vtk::Commands::Socks::On do
  it "executes `socks on` command successfully" do
    output = StringIO.new
    options = {}
    command = Vtk::Commands::Socks::On.new(options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
