require "bundler/setup"
require "rails"
require "action_mailer/railtie"
Bundler.require
require "action_mailer_cloudflare/fake_transport"

ROOT, ACCOUNT_ID, API_TOKEN = ARGV
CONTENT_PATH = File.join(ROOT, "credentials.yml.enc")
KEY_PATH = File.join(ROOT, "master.key")

File.write(KEY_PATH, ActiveSupport::EncryptedConfiguration.generate_key)
ActiveSupport::EncryptedConfiguration.new(config_path: CONTENT_PATH, key_path: KEY_PATH, env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true)
  .write({ "cloudflare_email" => { "account_id" => ACCOUNT_ID, "api_token" => API_TOKEN } }.to_yaml)

class RailsApp < Rails::Application
  config.root = ROOT
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.credentials.content_path = CONTENT_PATH
  config.credentials.key_path = KEY_PATH
  config.action_mailer.delivery_method = :cloudflare
  config.action_mailer.cloudflare_settings = { transport: ActionMailerCloudflare::FakeTransport.new }
end

RailsApp.initialize!

class HelloMailer < ActionMailer::Base
  def hello = mail(from: "a@example.com", to: "b@example.com", subject: "Hi", body: "Hi")
end

HelloMailer.hello.deliver_now
request = ActionMailer::Base.cloudflare_settings.fetch(:transport).sent.sole
puts JSON.generate(url: request.url, authorization: request.headers["Authorization"])
