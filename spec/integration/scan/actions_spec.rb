# frozen_string_literal: true

require 'English'

RSpec.describe '`vtk scan actions` command', type: :cli do
  let(:vtk) { 'bundle exec vtk' }

  it 'executes `vtk scan help actions` command successfully' do
    output = `#{vtk} scan help actions`
    expect(output).to include('vtk scan actions')
    expect(output).to include('--org')
    expect(output).to include('--action')
    expect(output).to include('--format')
    expect(output).to include('--depth')
    expect(output).to include('--external')
    expect(output).to include('Trace direct and transitive uses of GitHub Actions')
  end

  it 'errors when --org is missing' do
    output = `#{vtk} scan actions 2>&1`
    expect(output).to include('--org is required')
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end

  it 'errors when --action is missing' do
    output = `#{vtk} scan actions --org my-org 2>&1`
    expect(output).to include('--action is required')
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end
end
