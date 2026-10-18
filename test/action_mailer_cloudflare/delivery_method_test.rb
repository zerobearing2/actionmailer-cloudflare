require "test_helper"

class ActionMailerCloudflare::DeliveryMethodTest < ActiveSupport::TestCase
  ACCOUNT_ID = "0123456789abcdef0123456789abcdef"

  class TestMailer < ActionMailer::Base
    self.delivery_method = :cloudflare
    self.raise_delivery_errors = true

    def hello(subject: "Hi", body: "Hello", **headers)
      mail(from: "Example <notifications@send.example.com>", to: "a@example.com", subject:, body:, **headers)
    end

    def anonymous = mail(to: "a@example.com", subject: "Hi", body: "Hello")

    def unaddressed = mail(from: "notifications@send.example.com", subject: "Hi", body: "Hello")
  end

  setup do
    @transport = ActionMailerCloudflare::FakeTransport.new
    TestMailer.cloudflare_settings = { transport: @transport, account_id: ACCOUNT_ID, api_token: "test-token" }
  end

  test "the :cloudflare symbol names this delivery method" do
    assert_equal ActionMailerCloudflare::DeliveryMethod, ActionMailer::Base.delivery_methods[:cloudflare]
  end

  test "deliver_now posts the encoded message to the account's send_raw endpoint" do
    TestMailer.hello(cc: "c@example.com", bcc: "hidden@example.com").deliver_now

    request = @transport.sent.sole
    assert_equal "https://api.cloudflare.com/client/v4/accounts/#{ACCOUNT_ID}/email/sending/send_raw", request.url
    assert_equal "Bearer test-token", request.headers["Authorization"]
    assert_equal "application/json", request.headers["Content-Type"]
    assert_equal "notifications@send.example.com", request.json["from"]
    assert_equal [ "a@example.com", "c@example.com", "hidden@example.com" ], request.json["recipients"]
    assert_includes request.json["mime_message"], "Subject: Hi"
    assert_not_includes request.json["mime_message"], "Bcc:"
    assert_not_includes request.json["mime_message"], "hidden@example.com"
  end

  test "an em dash and an ampersand reach Cloudflare intact" do
    TestMailer.hello(subject: "Fish & Chips — today", body: "Lunch — $12 & up").deliver_now

    sent = Mail.new(@transport.sent.sole.json["mime_message"])
    assert_equal "Fish & Chips — today", sent.subject
    assert_equal "Lunch — $12 & up", sent.body.decoded.force_encoding(Encoding::UTF_8)
  end

  test "an api token missing from cloudflare_settings is read from ENV when the message is sent" do
    TestMailer.cloudflare_settings = { transport: @transport, account_id: ACCOUNT_ID }

    with_env("CLOUDFLARE_EMAIL_API_TOKEN" => "env-token") { TestMailer.hello.deliver_now }

    assert_equal "Bearer env-token", @transport.sent.sole.headers["Authorization"]
  end

  test "outside a Rails app, keys set nowhere raise Error naming where to set them" do
    TestMailer.cloudflare_settings = { transport: @transport }

    error = with_env("CLOUDFLARE_EMAIL_ACCOUNT_ID" => nil, "CLOUDFLARE_EMAIL_API_TOKEN" => nil) do
      assert_raises(ActionMailerCloudflare::Error) { TestMailer.hello.deliver_now }
    end

    assert_includes error.message, "CLOUDFLARE_EMAIL_ACCOUNT_ID"
    assert_empty @transport.sent
  end

  test "a message without a sender raises before anything is sent" do
    error = assert_raises(ActionMailerCloudflare::Error) { TestMailer.anonymous.deliver_now }

    assert_includes error.message, "sender"
    assert_empty @transport.sent
  end

  test "a message without recipients raises before anything is sent" do
    error = assert_raises(ActionMailerCloudflare::Error) { TestMailer.unaddressed.deliver_now }

    assert_includes error.message, "recipients"
    assert_empty @transport.sent
  end

  test "a refusal from Cloudflare raises Rejected out of deliver_now" do
    @transport.answer(status: 400, json: { success: false, errors: [ { code: 10200, message: "email.sending.error.email.too_big" } ] })

    assert_raises(ActionMailerCloudflare::Rejected) { TestMailer.hello.deliver_now }
  end

  test "with return_response, Mail's deliver! returns Cloudflare's answer" do
    TestMailer.cloudflare_settings = TestMailer.cloudflare_settings.merge(return_response: true)

    response = TestMailer.hello.message.deliver!

    assert_equal 200, response.status
    assert_equal true, JSON.parse(response.body)["success"]
  end

  private
    def with_env(values)
      original = values.keys.index_with { |name| ENV[name] }
      ENV.update(values)
      yield
    ensure
      ENV.update(original)
    end
end
