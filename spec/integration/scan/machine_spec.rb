# frozen_string_literal: true

require 'English'

RSpec.describe '`vtk scan machine` command', type: :cli do
  it 'executes `vtk scan help machine` command successfully' do
    output = `vtk scan help machine`
    expect(output).to include('vtk scan machine')
    expect(output).to include('--verbose')
    expect(output).to include('--json')
    expect(output).to include('--quiet')
    expect(output).to include('Shai-Hulud')
  end

  it 'executes `vtk scan machine` command with compact output' do
    output = `vtk scan machine 2>&1`

    expect(output).to include('Shai-Hulud Check:')
  end

  it 'executes `vtk scan machine --verbose` with detailed output' do
    output = `vtk scan machine --verbose 2>&1`

    expect(output).to include('Shai-Hulud Machine Infection Check')
    expect(output).to include('Critical Checks')
    expect(output).to include('High-Risk Checks')
    expect(output).to include('Credential Files')
  end

  it 'executes `vtk scan machine --quiet` with exit code only' do
    output = `vtk scan machine --quiet 2>&1`

    expect(output).to be_empty
  end

  it 'executes `vtk scan machine --json` with JSON output' do
    output = `vtk scan machine --json 2>&1`

    expect(output).to include('"status":')
    expect(output).to include('"critical_count":')
    expect(output).to include('"high_count":')
    expect(output).to include('"timestamp":')
  end

  it 'returns exit code 0, 1, or 2 based on scan results' do
    `vtk scan machine --quiet 2>&1`
    exit_code = $CHILD_STATUS.exitstatus

    # Exit code should be 0 (clean), 1 (infected), or 2 (warning)
    expect([0, 1, 2]).to include(exit_code)
  end
end
