# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'
require 'openssl'

module Vtk
  # XDG-compliant cache management for vtk
  # Stores cached data in $XDG_CACHE_HOME/vtk/ (defaults to ~/.cache/vtk/)
  class Cache
    COMPROMISED_PACKAGES_URL = 'https://raw.githubusercontent.com/Cobenian/shai-hulud-detect/main/compromised-packages.txt'
    DEFAULT_TTL = 86_400 # 24 hours in seconds

    # Minimum expected packages - if we get fewer, something is wrong
    MIN_EXPECTED_PACKAGES = 500

    # Expected header comment to validate file authenticity
    EXPECTED_HEADER = 'Shai-Hulud NPM Supply Chain Attack'

    class << self
      def cache_dir
        base = ENV['XDG_CACHE_HOME'] || File.expand_path('~/.cache')
        File.join(base, 'vtk')
      end

      def compromised_packages_file
        File.join(cache_dir, 'compromised-packages.txt')
      end

      # Fetch compromised packages list, using cache if fresh
      # @param refresh [Boolean] Force refresh even if cache is fresh
      # @param output [IO] Output stream for status messages
      # @return [Set<String>] Set of "package:version" strings
      def compromised_packages(refresh: false, output: $stderr)
        ensure_cache_dir

        fetch_compromised_packages(output) if refresh || cache_stale?(compromised_packages_file)

        load_compromised_packages(output)
      end

      private

      def ensure_cache_dir
        FileUtils.mkdir_p(cache_dir)
      end

      def cache_stale?(file_path, ttl: DEFAULT_TTL)
        return true unless File.exist?(file_path)

        File.mtime(file_path) < Time.now - ttl
      end

      def fetch_compromised_packages(output)
        output.puts 'Fetching compromised packages list...'

        uri = URI(COMPROMISED_PACKAGES_URL)
        body = fetch_with_ssl_verification(uri)

        validate_package_list!(body)

        File.write(compromised_packages_file, body)
        output.puts "Cached #{count_packages(body)} compromised packages"
      rescue StandardError => e
        raise unless File.exist?(compromised_packages_file)

        output.puts "WARNING: #{e.message}, using cached version"
      end

      def fetch_with_ssl_verification(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        # Enforce SSL/TLS security
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.min_version = OpenSSL::SSL::TLS1_2_VERSION

        # Use system CA certificates
        http.ca_file = find_ca_file if find_ca_file

        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'vtk-security-scanner'

        response = http.request(request)

        raise "Failed to fetch compromised packages list: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def find_ca_file
        # Common CA bundle locations
        ca_paths = [
          '/etc/ssl/certs/ca-certificates.crt',     # Debian/Ubuntu
          '/etc/pki/tls/certs/ca-bundle.crt',       # RHEL/CentOS
          '/etc/ssl/ca-bundle.pem', # OpenSUSE
          '/usr/local/share/certs/ca-root-nss.crt', # FreeBSD
          '/etc/ssl/cert.pem' # macOS
        ]

        ca_paths.find { |path| File.exist?(path) }
      end

      def validate_package_list!(body)
        # Check 1: File must contain expected header
        unless body.include?(EXPECTED_HEADER)
          raise 'Downloaded file missing expected header - possible MITM or corrupted file'
        end

        # Check 2: Must have minimum number of packages (prevents truncation attacks)
        package_count = count_packages(body)
        if package_count < MIN_EXPECTED_PACKAGES
          raise "Downloaded file has only #{package_count} packages " \
                "(expected #{MIN_EXPECTED_PACKAGES}+) - possible truncation"
        end

        # Check 3: Packages must be in expected format (name:version)
        valid_format = body.lines.select { |l| l.strip =~ /^[^#]/ }.all? do |line|
          line.strip.empty? || line.strip =~ %r{^[@a-zA-Z0-9][\w\-./]*:\d+\.\d+\.\d+}
        end

        return if valid_format

        raise 'Downloaded file contains invalid package format - possible corruption'
      end

      def load_compromised_packages(_output)
        unless File.exist?(compromised_packages_file)
          raise 'No compromised packages list available. Check your network connection.'
        end

        packages = Set.new
        File.foreach(compromised_packages_file) do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')
          next unless line.include?(':')

          packages.add(line)
        end

        packages
      end

      def count_packages(content)
        content.lines.count { |l| l.strip =~ /^[^#].*:/ }
      end
    end
  end
end
