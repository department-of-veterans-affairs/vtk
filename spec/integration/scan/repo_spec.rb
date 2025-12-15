# frozen_string_literal: true

require 'English'
require 'tmpdir'
require 'fileutils'
require 'json'

RSpec.describe '`vtk scan repo` command', type: :cli do
  let(:tmpdir) { Dir.mktmpdir('vtk-scan-repo-test') }
  let(:vtk) { 'bundle exec vtk' }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it 'executes `vtk scan help repo` command successfully' do
    output = `#{vtk} scan help repo`
    expect(output).to include('vtk scan repo')
    expect(output).to include('--refresh')
    expect(output).to include('--json')
    expect(output).to include('--quiet')
    expect(output).to include('--recursive')
    expect(output).to include('compromised packages')
  end

  it 'executes `vtk scan repo` on current directory' do
    output = `#{vtk} scan repo 2>&1`

    expect(output).to include('Scanning:')
    expect(output).to include('Status:')
  end

  it 'reports no lockfiles found for empty directory' do
    output = `#{vtk} scan repo #{tmpdir} 2>&1`

    expect(output).to include('No lockfiles found')
    expect(output).to include('CLEAN')
  end

  context 'with package-lock.json' do
    before do
      # Create a clean package-lock.json
      File.write(File.join(tmpdir, 'package-lock.json'), {
        'name' => 'test-project',
        'lockfileVersion' => 3,
        'packages' => {
          '' => { 'name' => 'test-project', 'version' => '1.0.0' },
          'node_modules/safe-package' => { 'version' => '1.0.0' }
        }
      }.to_json)
    end

    it 'scans package-lock.json and reports clean' do
      output = `#{vtk} scan repo #{tmpdir} 2>&1`

      expect(output).to include('Scanning:')
      expect(output).to include('CLEAN')
      expect(output).not_to include('COMPROMISED')
    end

    it 'outputs JSON when --json flag is used' do
      output = `#{vtk} scan repo #{tmpdir} --json 2>&1`

      result = JSON.parse(output)
      expect(result['status']).to eq('CLEAN')
      expect(result['compromised_packages']).to eq([])
      expect(result['backdoors']).to eq([])
    end

    it 'outputs nothing when --quiet flag is used' do
      output = `#{vtk} scan repo #{tmpdir} --quiet 2>&1`

      expect(output).to be_empty
    end
  end

  context 'with compromised package' do
    before do
      # Create a package-lock.json with a known compromised package
      # @ctrl/tinycolor:4.1.1 is in the compromised list
      File.write(File.join(tmpdir, 'package-lock.json'), {
        'name' => 'test-project',
        'lockfileVersion' => 3,
        'packages' => {
          '' => { 'name' => 'test-project', 'version' => '1.0.0' },
          'node_modules/@ctrl/tinycolor' => { 'version' => '4.1.1' }
        }
      }.to_json)
    end

    it 'detects compromised package and reports infected' do
      output = `#{vtk} scan repo #{tmpdir} 2>&1`

      expect(output).to include('COMPROMISED PACKAGES FOUND')
      expect(output).to include('@ctrl/tinycolor:4.1.1')
      expect(output).to include('INFECTED')
      expect(output).to include('playbook')
    end

    it 'returns exit code 1 for compromised packages' do
      `#{vtk} scan repo #{tmpdir} --quiet 2>&1`
      exit_code = $CHILD_STATUS.exitstatus

      expect(exit_code).to eq(1)
    end

    it 'includes compromised package in JSON output' do
      output = `#{vtk} scan repo #{tmpdir} --json 2>&1`

      result = JSON.parse(output)
      expect(result['status']).to include('INFECTED')
      expect(result['compromised_packages'].length).to eq(1)
      expect(result['compromised_packages'].first['package']).to eq('@ctrl/tinycolor:4.1.1')
    end
  end

  context 'with backdoor workflow' do
    before do
      # Create a malicious discussion.yaml workflow
      workflows_dir = File.join(tmpdir, '.github', 'workflows')
      FileUtils.mkdir_p(workflows_dir)

      File.write(File.join(workflows_dir, 'discussion.yaml'), <<~YAML)
        name: Discussion Handler
        on: discussion
        jobs:
          handle:
            runs-on: self-hosted
            steps:
              - run: echo "${{ github.event.discussion.body }}"
      YAML

      # Also need a lockfile to avoid the "no lockfiles" warning
      File.write(File.join(tmpdir, 'package-lock.json'), {
        'name' => 'test-project',
        'lockfileVersion' => 3,
        'packages' => {}
      }.to_json)
    end

    it 'detects backdoor workflow and reports warning' do
      output = `#{vtk} scan repo #{tmpdir} 2>&1`

      expect(output).to include('BACKDOOR WORKFLOWS FOUND')
      expect(output).to include('discussion.yaml')
      expect(output).to include('discussion_backdoor')
    end

    it 'returns exit code 2 for backdoor workflow' do
      `#{vtk} scan repo #{tmpdir} --quiet 2>&1`
      exit_code = $CHILD_STATUS.exitstatus

      expect(exit_code).to eq(2)
    end
  end

  context 'with formatter workflow (secrets extraction)' do
    before do
      workflows_dir = File.join(tmpdir, '.github', 'workflows')
      FileUtils.mkdir_p(workflows_dir)

      File.write(File.join(workflows_dir, 'formatter_123456789.yml'), <<~YAML)
        name: Formatter
        on: push
        jobs:
          extract:
            runs-on: ubuntu-latest
            steps:
              - run: echo "secrets"
      YAML

      File.write(File.join(tmpdir, 'package-lock.json'), {
        'name' => 'test-project',
        'lockfileVersion' => 3,
        'packages' => {}
      }.to_json)
    end

    it 'detects secrets extraction workflow' do
      output = `#{vtk} scan repo #{tmpdir} 2>&1`

      expect(output).to include('BACKDOOR WORKFLOWS FOUND')
      expect(output).to include('formatter_123456789.yml')
      expect(output).to include('secrets_extraction')
    end
  end

  it 'returns exit code 0, 1, or 2 based on scan results' do
    `#{vtk} scan repo --quiet 2>&1`
    exit_code = $CHILD_STATUS.exitstatus

    expect([0, 1, 2]).to include(exit_code)
  end

  context 'with --recursive flag' do
    before do
      # Create nested directories with lockfiles
      subdir1 = File.join(tmpdir, 'packages', 'app1')
      subdir2 = File.join(tmpdir, 'packages', 'app2')
      FileUtils.mkdir_p(subdir1)
      FileUtils.mkdir_p(subdir2)

      # Clean lockfile in subdir1
      File.write(File.join(subdir1, 'package-lock.json'), {
        'name' => 'app1',
        'lockfileVersion' => 3,
        'packages' => {
          '' => { 'name' => 'app1', 'version' => '1.0.0' },
          'node_modules/safe-package' => { 'version' => '1.0.0' }
        }
      }.to_json)

      # Compromised lockfile in subdir2
      File.write(File.join(subdir2, 'package-lock.json'), {
        'name' => 'app2',
        'lockfileVersion' => 3,
        'packages' => {
          '' => { 'name' => 'app2', 'version' => '1.0.0' },
          'node_modules/@ctrl/tinycolor' => { 'version' => '4.1.1' }
        }
      }.to_json)
    end

    it 'does not find nested lockfiles without --recursive' do
      output = `#{vtk} scan repo #{tmpdir} 2>&1`

      expect(output).to include('No lockfiles found')
      expect(output).to include('CLEAN')
    end

    it 'finds nested lockfiles with --recursive' do
      output = `#{vtk} scan repo #{tmpdir} --recursive 2>&1`

      expect(output).to include('COMPROMISED PACKAGES FOUND')
      expect(output).to include('@ctrl/tinycolor:4.1.1')
      expect(output).to include('packages/app2')
    end

    it 'finds nested lockfiles with -r shorthand' do
      output = `#{vtk} scan repo #{tmpdir} -r 2>&1`

      expect(output).to include('COMPROMISED PACKAGES FOUND')
      expect(output).to include('@ctrl/tinycolor:4.1.1')
    end

    it 'includes all nested lockfiles in JSONL output' do
      output = `#{vtk} scan repo #{tmpdir} --recursive --json 2>&1`

      # JSONL format: one JSON object per line
      lines = output.strip.split("\n")
      results = lines.map { |line| JSON.parse(line) }

      # Find the infected lockfile and summary
      lockfile_results = results.reject { |r| r['type'] == 'summary' }
      summary = results.find { |r| r['type'] == 'summary' }

      expect(lockfile_results.length).to eq(2)
      infected = lockfile_results.find { |r| r['status'] == 'INFECTED' }
      expect(infected['lockfile']).to include('packages/app2')
      expect(infected['compromised_packages']).to include('@ctrl/tinycolor:4.1.1')

      expect(summary['status']).to eq('INFECTED')
      expect(summary['total_compromised']).to eq(1)
    end
  end

  context 'with --recursive flag and nested workflows' do
    before do
      # Create nested repo structure
      nested_repo = File.join(tmpdir, 'repos', 'nested-project')
      workflows_dir = File.join(nested_repo, '.github', 'workflows')
      FileUtils.mkdir_p(workflows_dir)

      # Backdoor workflow in nested directory
      File.write(File.join(workflows_dir, 'discussion.yaml'), <<~YAML)
        name: Discussion Handler
        on: discussion
        jobs:
          handle:
            runs-on: self-hosted
            steps:
              - run: echo "${{ github.event.discussion.body }}"
      YAML

      # Lockfile in nested directory to avoid warning
      File.write(File.join(nested_repo, 'package-lock.json'), {
        'name' => 'nested-project',
        'lockfileVersion' => 3,
        'packages' => {}
      }.to_json)
    end

    it 'does not find nested workflows without --recursive' do
      output = `#{vtk} scan repo #{tmpdir} 2>&1`

      expect(output).not_to include('BACKDOOR WORKFLOWS FOUND')
    end

    it 'finds nested workflows with --recursive' do
      output = `#{vtk} scan repo #{tmpdir} --recursive 2>&1`

      expect(output).to include('BACKDOOR WORKFLOWS FOUND')
      expect(output).to include('repos/nested-project')
      expect(output).to include('discussion.yaml')
    end
  end
end
