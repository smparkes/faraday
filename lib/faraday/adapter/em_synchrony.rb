require 'em-synchrony/em-http'

module Faraday
  module Adapter
    class EMSynchrony < Middleware
      def call(env)
        process_body_for_request(env)
        
        request = EventMachine::HttpRequest.new(URI::parse(env[:url].to_s))
        
        options = {:head => env[:request_headers]}

        if env[:body]
          options[:body] = env[:body]
        end

        if req = env[:request]
          if proxy = req[:proxy]
            uri = Addressable::URI.parse(proxy[:uri])
            options[:proxy] = {
              :host => uri.host,
              :port => uri.port
            }
            if proxy[:username] && proxy[:password]
              options[:proxy][:authorization] = [proxy[:username], proxy[:password]]
            end
          end

          # only one timeout currently supported by em http request
          if req[:timeout] or req[:open_timeout]
            options[:timeout] = [req[:timeout] || 0, req[:open_timeout] || 0].max
          end
        end

        client = request.send env[:method].to_s.downcase.to_sym, options

        resp_headers = {}
        client.response_header.each do |key, value|
          resp_headers[key] = value
        end

        env.update \
          :status           => client.response_header.http_status.to_i,
          :response_headers => resp_headers, 
          :body             => client.response

        @app.call env
      rescue Errno::ECONNREFUSED
        raise Error::ConnectionFailed, "connection refused"
      end
    end
  end
end
