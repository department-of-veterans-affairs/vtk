# frozen_string_literal: true

require 'json'

module Vtk
  # Parses npm/yarn/pnpm lockfiles to extract package versions
  class LockfileParser
    # Parse a lockfile and return package:version pairs
    # @param path [String] Path to the lockfile
    # @return [Array<String>] Array of "package:version" strings
    def self.parse(path)
      return [] unless File.exist?(path)

      case File.basename(path)
      when 'package-lock.json'
        parse_package_lock(path)
      when 'yarn.lock'
        parse_yarn_lock(path)
      when 'pnpm-lock.yaml'
        parse_pnpm_lock(path)
      else
        []
      end
    end

    # Find lockfiles in a directory
    # @param dir [String] Directory to search
    # @return [Array<String>] Paths to lockfiles found
    def self.find_lockfiles(dir)
      lockfiles = []
      %w[package-lock.json yarn.lock pnpm-lock.yaml].each do |name|
        path = File.join(dir, name)
        lockfiles << path if File.exist?(path)
      end
      lockfiles
    end

    class << self
      private

      # Parse package-lock.json (npm)
      # Handles v1 (dependencies), v2 (packages + dependencies), and v3 (packages) formats
      def parse_package_lock(path)
        content = JSON.parse(File.read(path))
        packages = []

        # v2/v3 format: "packages" key with node_modules paths
        content['packages']&.each do |pkg_path, info|
          next if pkg_path.empty? # Skip root package
          next unless info['version']

          # Extract package name from path like "node_modules/@scope/pkg"
          name = pkg_path.sub(%r{^node_modules/}, '')
          packages << "#{name}:#{info['version']}"
        end

        # v1 format: "dependencies" key (also present in v2 for compatibility)
        extract_dependencies(content['dependencies'], packages) if content['dependencies']

        packages.uniq
      end

      def extract_dependencies(deps, packages, prefix = '')
        deps.each do |name, info|
          next unless info.is_a?(Hash) && info['version']

          full_name = prefix.empty? ? name : "#{prefix}/#{name}"
          packages << "#{full_name}:#{info['version']}"

          # Handle nested dependencies
          extract_dependencies(info['dependencies'], packages, full_name) if info['dependencies']
        end
      end

      # Parse yarn.lock (yarn v1)
      # Format:
      #   "package@^1.0.0":
      #     version "1.2.3"
      def parse_yarn_lock(path)
        content = File.read(path)
        packages = []

        current_package = nil
        content.each_line do |line|
          # Match package declaration: "pkg@version", pkg@version:
          if line =~ /^["']?([^@]+)@[^:]+["']?:?\s*$/
            current_package = Regexp.last_match(1).strip.delete('"\'')
          # Match version line
          elsif line =~ /^\s+version\s+["']?([^"'\s]+)["']?/ && current_package
            version = Regexp.last_match(1)
            packages << "#{current_package}:#{version}"
            current_package = nil
          end
        end

        packages.uniq
      end

      # Parse pnpm-lock.yaml
      # Format:
      #   packages:
      #     /@scope/pkg@1.2.3:
      #       ...
      def parse_pnpm_lock(path)
        content = File.read(path)
        packages = []

        in_packages = false
        content.each_line do |line|
          if line =~ /^packages:/
            in_packages = true
            next
          end

          # Exit packages section on next top-level key
          if in_packages && line =~ /^\w+:/
            in_packages = false
            next
          end

          next unless in_packages

          # Match package entries like:
          #   /@scope/pkg@1.2.3:
          #   /pkg@1.2.3:
          #   '@scope/pkg@1.2.3':
          next unless line =~ %r{^\s{2}['"]?/?(@?[^@:]+)@([^:'"\s]+)['"]?:}

          name = Regexp.last_match(1)
          version = Regexp.last_match(2)
          packages << "#{name}:#{version}"
        end

        packages.uniq
      end
    end
  end
end
