require "test_helper"

class ActionMailerCloudflare::HttpTransportTest < ActiveSupport::TestCase
  URL = "https://api.cloudflare.com/client/v4/accounts/0123456789abcdef0123456789abcdef/email/sending/send_raw"

  test "a post uses TLS and the timeouts, and returns the status and body" do
    captured = {}
    http = Object.new
    http.define_singleton_method(:request) do |request|
      captured[:request] = request
      Struct.new(:code, :body).new("202", '{"success":true}')
    end

    response = with_net_http_start(captured, -> { http }) do
      ActionMailerCloudflare::HttpTransport.new.post(URL, headers: { "Authorization" => "Bearer t" }, body: '{"from":"a@example.com"}')
    end

    assert_equal 202, response.status
    assert_equal '{"success":true}', response.body
    assert_equal [ "api.cloudflare.com", 443 ], captured[:args]
    assert_equal({ use_ssl: true, open_timeout: 5, read_timeout: 30, write_timeout: 30 }, captured[:kwargs])
    assert_equal "POST", captured[:request].method
    assert_equal "/client/v4/accounts/0123456789abcdef0123456789abcdef/email/sending/send_raw", captured[:request].path
    assert_equal "Bearer t", captured[:request]["Authorization"]
    assert_equal '{"from":"a@example.com"}', captured[:request].body
  end

  test "a failure before the request leaves is Unsent" do
    [ SocketError.new("getaddrinfo"), Errno::ECONNREFUSED.new, Errno::EHOSTUNREACH.new, Net::OpenTimeout.new ].each do |failure|
      error = assert_raises(ActionMailerCloudflare::Unsent, failure.class.name) { post_failing_with(failure) }

      assert_includes error.message, "not sent"
    end
  end

  test "a failure after the request may have arrived leaves the outcome unknown" do
    [ Net::ReadTimeout.new, Net::WriteTimeout.new, Errno::ECONNRESET.new, OpenSSL::SSL::SSLError.new, EOFError.new, Net::HTTPBadResponse.new ].each do |failure|
      error = assert_raises(ActionMailerCloudflare::Unavailable, failure.class.name) { post_failing_with(failure) }

      assert_instance_of ActionMailerCloudflare::Unavailable, error, failure.class.name
      assert_includes error.message, "outcome unknown"
    end
  end

  private
    def post_failing_with(failure)
      with_net_http_start({}, -> { raise failure }) do
        ActionMailerCloudflare::HttpTransport.new.post(URL, headers: {}, body: "{}")
      end
    end

    def with_net_http_start(captured, connect)
      original = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) do |*args, **kwargs, &block|
        captured[:args] = args
        captured[:kwargs] = kwargs
        block.call(connect.call)
      end
      yield
    ensure
      Net::HTTP.singleton_class.define_method(:start, original)
    end
end
