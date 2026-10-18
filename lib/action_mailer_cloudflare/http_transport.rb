require "net/http"

module ActionMailerCloudflare
  class HttpTransport
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    WRITE_TIMEOUT = 30
    UNSENT = [ SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout ]
    UNKNOWN = [ Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, Net::ProtocolError, IOError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError ]

    # UNSENT is rescued first: Net::OpenTimeout is a Timeout::Error and Errno::* are SystemCallErrors.
    def post(url, headers:, body:)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri, headers)
      request.body = body
      response = start(uri) { |http| http.request(request) }
      Response.new(status: Integer(response.code), body: response.body.to_s)
    rescue *UNSENT => e
      raise Unsent, "Cloudflare Email not sent, #{e.class}: #{e.message}"
    rescue *UNKNOWN => e
      raise Unavailable, "Cloudflare Email outcome unknown, #{e.class}: #{e.message}"
    end

    private
      def start(uri, &)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, write_timeout: WRITE_TIMEOUT, &)
      end
  end
end
