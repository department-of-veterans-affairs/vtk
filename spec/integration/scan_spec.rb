# frozen_string_literal: true

RSpec.describe '`vtk scan` command', type: :cli do
  it 'executes `vtk scan help` command successfully' do
    output = `vtk scan help`

    expect(output).to include('vtk scan help [COMMAND]')
    expect(output).to include('vtk scan machine')
    expect(output).to include('vtk scan credentials')
  end
end
