RSpec.describe "`vtk socks on` command", type: :cli do
  it "executes `vtk socks help on` command successfully" do
    output = `vtk socks help on`
    expected_output = <<-OUT
Usage:
  vtk on

Options:
  -h, [--help], [--no-help]  # Display usage information

Command description...
    OUT

    expect(output).to eq(expected_output)
  end
end
