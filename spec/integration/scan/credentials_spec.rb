# frozen_string_literal: true

require 'English'

RSpec.describe '`vtk scan credentials` command', type: :cli do
  it 'executes `vtk scan help credentials` command successfully' do
    output = `vtk scan help credentials`
    expect(output).to include('vtk scan credentials')
    expect(output).to include('--verbose')
    expect(output).to include('--json')
    expect(output).to include('security incident')
  end

  it 'executes `vtk scan credentials` command with standard output' do
    output = `vtk scan credentials 2>&1`

    expect(output).to include('Credential Audit')
  end

  it 'executes `vtk scan credentials --verbose` with all checks' do
    output = `vtk scan credentials --verbose 2>&1`

    expect(output).to include('Credential Audit')
    expect(output).to include('NPM')
    expect(output).to include('AWS')
    expect(output).to include('GCP')
    expect(output).to include('Azure')
    expect(output).to include('GitHub')
    expect(output).to include('SSH')
    expect(output).to include('Docker')
    expect(output).to include('Kubernetes')
  end

  it 'executes `vtk scan credentials --json` with JSON output' do
    output = `vtk scan credentials --json 2>&1`

    expect(output).to include('"status":')
    expect(output).to include('"credentials_found":')
    expect(output).to include('"credentials":')
    expect(output).to include('"timestamp":')
  end

  it 'returns exit code 0 or 1 based on credentials found' do
    `vtk scan credentials --quiet 2>&1`
    exit_code = $CHILD_STATUS.exitstatus

    # Exit code should be 0 (no credentials) or 1 (credentials found)
    expect([0, 1]).to include(exit_code)
  end

  it 'includes rotation instructions when credentials are found' do
    output = `vtk scan credentials 2>&1`
    exit_code = $CHILD_STATUS.exitstatus

    expect(output).to include('Rotation Instructions') if exit_code == 1
  end
end
