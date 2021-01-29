# frozen_string_literal: true

RSpec.describe '`vtk socks` command', type: :cli do
  it 'executes `vtk help socks` command successfully' do
    output = `vtk help socks`
    expected_output = <<-OUT
Commands:
    OUT

    expect(output).to eq(expected_output)
  end
end
