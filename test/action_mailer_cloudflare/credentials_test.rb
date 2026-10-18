require "test_helper"

class ActionMailerCloudflare::CredentialsTest < ActiveSupport::TestCase
  SETTINGS_ID = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  ENV_ID = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  STORE_ID = "cccccccccccccccccccccccccccccccc"
  ENV_VARS = { "CLOUDFLARE_EMAIL_ACCOUNT_ID" => ENV_ID, "CLOUDFLARE_EMAIL_API_TOKEN" => "env-token" }
  STORE = { cloudflare_email: { account_id: STORE_ID, api_token: "store-token" } }

  test "cloudflare_settings win over ENV and credentials" do
    credentials = build(settings: { account_id: SETTINGS_ID, api_token: "settings-token" }, env: ENV_VARS, store: STORE)

    assert_equal SETTINGS_ID, credentials.account_id
    assert_equal "settings-token", credentials.api_token
  end

  test "ENV wins over credentials" do
    credentials = build(env: ENV_VARS, store: STORE)

    assert_equal ENV_ID, credentials.account_id
    assert_equal "env-token", credentials.api_token
  end

  test "credentials are the last resort" do
    credentials = build(store: STORE)

    assert_equal STORE_ID, credentials.account_id
    assert_equal "store-token", credentials.api_token
  end

  test "each key resolves on its own, and a blank value falls through" do
    credentials = build(settings: { account_id: "", api_token: nil }, env: { "CLOUDFLARE_EMAIL_ACCOUNT_ID" => ENV_ID, "CLOUDFLARE_EMAIL_API_TOKEN" => " " }, store: STORE)

    assert_equal ENV_ID, credentials.account_id
    assert_equal "store-token", credentials.api_token
  end

  test "a missing key names both places to set it" do
    error = assert_raises(ActionMailerCloudflare::Error) { build(store: { cloudflare_email: { account_id: STORE_ID } }) }

    assert_includes error.message, "CLOUDFLARE_EMAIL_API_TOKEN"
    assert_includes error.message, "cloudflare_email.api_token"
  end

  test "an account id that is not 32 hex characters is rejected without echoing it" do
    [ "0123456789abcdef0123456789abcde", "0123456789abcdef0123456789abcdef/../x", "not-an-id-but-maybe-a-token-0000" ].each do |account_id|
      error = assert_raises(ActionMailerCloudflare::Error, account_id) { build(settings: { account_id: }, store: STORE) }

      assert_includes error.message, "account_id"
      assert_not_includes error.message, account_id
    end
  end

  test "a token with whitespace is rejected without echoing it" do
    error = assert_raises(ActionMailerCloudflare::Error) { build(settings: { api_token: "secret-token\n" }, store: STORE) }

    assert_includes error.message, "api_token"
    assert_not_includes error.message, "secret-token"
  end

  test "inspect shows the account id and redacts the token" do
    credentials = build(store: STORE)

    assert_includes credentials.inspect, STORE_ID
    assert_includes credentials.inspect, "[REDACTED]"
    assert_not_includes credentials.inspect, "store-token"
  end

  private
    def build(settings: {}, env: {}, store: {})
      ActionMailerCloudflare::Credentials.new(settings:, env:, store:)
    end
end
