require 'json'
require 'net/http'
require 'openssl'

module Reckoning
  class Client
    class Connection
      def initialize(url, api_key)
        @url = url.to_s.chomp('/')
        @api_key = api_key
      end

      def request(method, path, body = nil)
        uri = URI("#{@url}#{path}")
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 60) do |http|
          http.request(build(method, uri, body))
        end
        [response.code.to_i, parsed(response)]
      rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
        raise Unreachable.new("could not reach the service at #{@url}: #{e.message}")
      end

      private

      def build(method, uri, body)
        Net::HTTP.const_get(method.to_s.capitalize).new(uri).tap do |request|
          request['Authorization'] = "Bearer #{@api_key}"
          request['Content-Type'] = 'application/json'
          request['Accept'] = 'application/json'
          request.body = JSON.generate(Values.write(body)) if body
        end
      end

      def parsed(response)
        JSON.parse(response.body.to_s.empty? ? '{}' : response.body)
      rescue JSON::ParserError
        {'error' => "the service answered HTTP #{response.code} with something other than JSON"}
      end
    end
  end
end
