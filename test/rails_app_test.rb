require "test_helper"
require "open3"
require "tmpdir"

class ActionMailerCloudflare::RailsAppTest < ActiveSupport::TestCase
  ACCOUNT_ID = "0123456789abcdef0123456789abcdef"
  CLEAN_ENV = { "RAILS_MASTER_KEY" => nil, "CLOUDFLARE_EMAIL_ACCOUNT_ID" => nil, "CLOUDFLARE_EMAIL_API_TOKEN" => nil }

  test "a Rails app that sets cloudflare_settings in config boots and sends with its credentials" do
    stdout, stderr, status = Dir.mktmpdir do |root|
      Open3.capture3(CLEAN_ENV, RbConfig.ruby, File.expand_path("fixtures/rails_app.rb", __dir__), root, ACCOUNT_ID, "credentials-token")
    end

    assert status.success?, stderr
    request = JSON.parse(stdout.lines.last)
    assert_equal "https://api.cloudflare.com/client/v4/accounts/#{ACCOUNT_ID}/email/sending/send_raw", request["url"]
    assert_equal "Bearer credentials-token", request["authorization"]
  end
end
