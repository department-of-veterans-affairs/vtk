RSpec.describe "`vtk socks setup` command", type: :cli do
  it "executes `vtk socks help setup` command successfully" do
    output = `vtk socks help setup`
    expected_output = <<-OUT
Usage:
  vtk setup

Options:
  -h, [--help], [--no-help]  # Display usage information

Command description...
    OUT

    expect(output).to eq(expected_output)
  end
end
