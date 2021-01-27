# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open-uri'
require 'uri'

module Vtk
  # Provides command analytics to VTK team
  class Analytics
    CLIENT_KEY = ''

    attr_reader :args, :hostname

    def initialize(name:, hostname: nil)
      @args = name
      @hostname = hostname || `hostname -f`.chomp
    end

    def log
      return if ENV['CI'] || ENV['TEST']

      Process.fork do
        exit unless internet?

        emit_point
      rescue StandardError
        false # Silently error
      end
    end

    def emit_point
      uri = URI.parse "https://api.datadoghq.com/api/v1/series?api_key=#{CLIENT_KEY}"
      Net::HTTP.start uri.host, uri.port, use_ssl: true do |http|
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
        tags: "args:#{args}",
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
