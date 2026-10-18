require "test_helper"

class ActionMailerCloudflare::ResponseTest < ActiveSupport::TestCase
  test "an accepted message verifies as itself" do
    response = respond(200, ActionMailerCloudflare::FakeTransport::ACCEPTED)

    assert_same response, response.verify!
  end

  test "a success without a result is still accepted" do
    response = respond(202, success: true, errors: [])

    assert_same response, response.verify!
  end

  test "a permanent bounce in a 2xx is a rejection that names no address" do
    error = assert_raises(ActionMailerCloudflare::Rejected) do
      respond(200, success: true, result: { delivered: [], permanent_bounces: [ "gone@example.com" ], queued: [] }).verify!
    end

    assert_includes error.message, "1 recipient"
    assert_not_includes error.message, "gone@example.com"
  end

  test "a 2xx that does not say success leaves the outcome unknown" do
    [ { success: false, errors: [] }, { errors: [] }, [ ActionMailerCloudflare::FakeTransport::ACCEPTED ] ].each do |json|
      error = assert_raises(ActionMailerCloudflare::Unavailable) { respond(200, json).verify! }

      assert_instance_of ActionMailerCloudflare::Unavailable, error, json.inspect
      assert_includes error.message, "outcome unknown"
    end
  end

  test "a 2xx that is not JSON leaves the outcome unknown" do
    error = assert_raises(ActionMailerCloudflare::Unavailable) { ActionMailerCloudflare::Response.new(status: 200, body: "<html>").verify! }

    assert_instance_of ActionMailerCloudflare::Unavailable, error
  end

  test "a 429 was not sent" do
    error = assert_raises(ActionMailerCloudflare::Unsent) { respond(429, success: false, errors: [ { code: 10004, message: "rate limited" } ]).verify! }

    assert_includes error.message, "HTTP 429"
    assert_includes error.message, "10004 rate limited"
  end

  test "any other 4xx is a rejection carrying Cloudflare's error codes" do
    [ 400, 401, 403, 404, 413, 422 ].each do |status|
      error = assert_raises(ActionMailerCloudflare::Rejected, status.to_s) do
        respond(status, success: false, errors: [ { code: 10200, message: "email.sending.error.email.too_big" } ]).verify!
      end

      assert_includes error.message, "HTTP #{status}"
      assert_includes error.message, "10200 email.sending.error.email.too_big"
    end
  end

  test "a 5xx or an unexpected status leaves the outcome unknown" do
    [ 500, 502, 503, 504, 301 ].each do |status|
      error = assert_raises(ActionMailerCloudflare::Unavailable, status.to_s) { ActionMailerCloudflare::Response.new(status:, body: "").verify! }

      assert_instance_of ActionMailerCloudflare::Unavailable, error, status.to_s
      assert_includes error.message, "outcome unknown"
    end
  end

  private
    def respond(status, json)
      ActionMailerCloudflare::Response.new(status:, body: JSON.generate(json))
    end
end
