# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open-uri'
require 'uri'

module Vtk
  # Provides command analytics to VTK team
  class Analytics
    attr_reader :name, :args, :hostname

    def initialize(name:, args: nil, hostname: nil)
      @name = name
      @args = args || ARGV.join('_')
      @hostname = hostname || `hostname -f`.chomp
    end

    def log
      return if ENV['CI'] || ENV['TEST'] || ENV['VTK_DISABLE_ANALYTICS']

      Process.fork do
        exit unless internet?

        emit_point
      rescue StandardError
        false # Silently error
      end
    end

    def emit_point
      uri = URI.parse 'https://dev.va.gov/_vfs/vtk-analytics/record'
      Net::HTTP.start uri.host, uri.port, use_ssl: uri.scheme == 'https' do |http|
        request = Net::HTTP::Post.new uri, 'Content-Type' => 'application/json'
        request.body = { series: [point] }.to_json
        http.request request
      end
    end

    def point
      {
        metric: 'vtk.command_executed',
        type: 'count',
        interval: 1,
        tags: ["name:#{name}", "args:#{args}"],
        host: hostname,
        points: [[Time.now.utc.to_i, '1']]
      }
    end

    def internet?
      true if URI.open 'http://www.google.com/'
    rescue SocketError
      false
    end
  end
end
