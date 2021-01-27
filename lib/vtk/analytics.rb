# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open-uri'
require 'uri'

module Vtk
  # Provides command analytics to VTK team
  class Analytics
    CLIENT_KEY = ''

    attr_reader :name, :title, :hostname

    def initialize(name:, title:, hostname: nil)
      @name = "vtk.#{name}"
      @title = "VTK #{title}"
      @hostname = hostname || `hostname -f`.chomp
    end

    def log
      return if ENV['CI'] || ENV['TEST']

      Process.fork do
        exit unless internet?

        emit_event
      rescue StandardError
        false # Silently error
      end
    end

    def emit_event
      uri = URI.parse "https://api.datadoghq.com/api/v1/events?api_key=#{CLIENT_KEY}"
      Net::HTTP.start uri.host, uri.port, use_ssl: true do |http|
        request = Net::HTTP::Post.new uri, 'Content-Type' => 'application/json'
        request.body = { title: title, text: name, date_happened: Time.now.utc.to_i, host: hostname }.to_json
        http.request request
      end
    end

    def internet?
      true if URI.open 'http://www.google.com/'
    rescue SocketError
      false
    end
  end
end
