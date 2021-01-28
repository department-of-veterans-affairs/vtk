RSpec.describe "`vtk socks off` command", type: :cli do
  it "executes `vtk socks help off` command successfully" do
    output = `vtk socks help off`
    expected_output = <<-OUT
Usage:
  vtk off

Options:
  -h, [--help], [--no-help]  # Display usage information

Command description...
    OUT

    expect(output).to eq(expected_output)
  end
end
