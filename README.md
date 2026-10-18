# actionmailer-cloudflare

An ActionMailer delivery method that sends mail through the Cloudflare Email Sending API. It posts the message ActionMailer already built to the `send_raw` endpoint over HTTPS, so it works on hosts that block outbound SMTP.

Requires Ruby 3.2 or later and ActionMailer 7.2, 8.0, or 8.1. CI runs the suite on Ruby 4.0 against each of those ActionMailer versions.

## Install the gem

The gem is not on RubyGems. Install it from GitHub, pinned to a release tag:

```ruby
# Gemfile
gem "actionmailer-cloudflare", github: "zerobearing2/actionmailer-cloudflare", tag: "v0.1.0"
```

Run `bundle install`. Bundler requires the gem for you, so the line needs no `require:` option. To upgrade, change the tag and run `bundle update actionmailer-cloudflare`.

## Send mail through Cloudflare

1. Onboard the domain you send from under **Email Service > Email Sending** in the Cloudflare dashboard.
2. Create an API token with the **Email Sending: Edit** permission.
3. Copy your account ID from the Cloudflare dashboard. It is 32 hexadecimal characters.
4. Add the account ID and the token to your Rails credentials with `bin/rails credentials:edit`:

   ```yaml
   cloudflare_email:
     account_id: 0123456789abcdef0123456789abcdef
     api_token: your-token
   ```

5. Set the delivery method in `config/environments/production.rb`:

   ```ruby
   config.action_mailer.delivery_method = :cloudflare
   config.action_mailer.raise_delivery_errors = true
   ```

`raise_delivery_errors` is `true` by default. If you set it to `false`, ActionMailer swallows every error below, and a job never sees a failure to retry.

### Set the keys from ENV or config instead

The gem reads the account ID and the token when a message is sent, not at boot. A missing key fails the first send, and `assets:precompile` without a master key still works. For each key, the first non-blank value in this order wins:

| Key | 1. `cloudflare_settings` | 2. ENV | 3. Rails credentials |
|---|---|---|---|
| Account ID | `account_id:` | `CLOUDFLARE_EMAIL_ACCOUNT_ID` | `cloudflare_email.account_id` |
| API token | `api_token:` | `CLOUDFLARE_EMAIL_API_TOKEN` | `cloudflare_email.api_token` |

Each key resolves on its own, so you can keep the account ID in credentials and pass the token through ENV. To read a key from somewhere else, set it in config:

```ruby
config.action_mailer.cloudflare_settings = { api_token: ENV["MAIL_TOKEN"] }
```

The account ID must be 32 hexadecimal characters, because it goes into the request URL. The token must contain no whitespace. A missing or malformed key raises `ActionMailerCloudflare::Error`, which names the three places to set it and never includes the value.

### Use it without Rails

The delivery method works with the `mail` gem alone. Outside a Rails app there are no Rails credentials, so set the keys in ENV or pass them as settings:

```ruby
require "mail"
require "actionmailer-cloudflare"

Mail.defaults do
  delivery_method ActionMailerCloudflare::DeliveryMethod, account_id: "0123456789abcdef0123456789abcdef", api_token: ENV["MAIL_TOKEN"]
end
```

## Retry only what Cloudflare never accepted

Every error the gem raises is a subclass of `ActionMailerCloudflare::Error`. The class tells you whether sending again is safe.

| Error | Raised when | Safe to retry |
|---|---|---|
| `ActionMailerCloudflare::Error` | A key is missing or malformed, or the message has no sender or no recipients. Nothing was sent. | No. Fix the configuration or the message. |
| `ActionMailerCloudflare::Rejected` | Cloudflare answered 4xx other than 429, or a 2xx that lists a permanent bounce. | No. Cloudflare refuses the same message the same way. After a permanent bounce, the other recipients may already have it. |
| `ActionMailerCloudflare::Unavailable` | Cloudflare answered 5xx or another unexpected status, or a 2xx without `"success": true`. Also raised when the connection fails after the request may have reached Cloudflare, such as a read timeout or a reset. | Not automatically. Cloudflare may have sent the message, so a retry can deliver a duplicate. |
| `ActionMailerCloudflare::Unsent` | Cloudflare answered 429, or the connection failed before the request left: DNS failure, connection refused, host unreachable, or open timeout. | Yes. Cloudflare never accepted the message, so a retry cannot duplicate it. |

`Unsent` is a subclass of `Unavailable`, so `rescue ActionMailerCloudflare::Unavailable` also catches `Unsent`. The gem itself never retries or sleeps.

To retry `deliver_later` mail on `Unsent` only, subclass `ActionMailer::MailDeliveryJob` and point your mailers at it:

```ruby
# app/jobs/mail_delivery_job.rb
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on ActionMailerCloudflare::Unsent, wait: :polynomially_longer, attempts: 5
end
```

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  self.delivery_job = MailDeliveryJob
end
```

A message that raises `Unavailable` then fails the job, and someone decides whether to send it again. If your own job calls `deliver_now`, put the same `retry_on` line on that job.

## Settings

`cloudflare_settings` accepts these keys:

| Key | Effect |
|---|---|
| `account_id` | The Cloudflare account ID. Overrides ENV and credentials. |
| `api_token` | The API token. Overrides ENV and credentials. |
| `return_response` | When `true`, `Mail::Message#deliver!` returns the `ActionMailerCloudflare::Response`, which has the HTTP `status` and the raw `body`. |
| `transport` | An object that responds to `post(url, headers:, body:)` and returns an `ActionMailerCloudflare::Response`. Use it in tests. |

The HTTP transport opens the connection with a 5-second timeout and waits 30 seconds for the request to write and for the response to arrive. These timeouts are fixed.

## Test your mailers against a fake Cloudflare

Most tests should keep `delivery_method = :test`. To test how your app handles a Cloudflare answer, such as a retry after a 429, use `FakeTransport`. It records every request and answers with the response you give it.

```ruby
require "action_mailer_cloudflare/fake_transport"

class WelcomeDeliveryTest < ActiveSupport::TestCase
  setup do
    @transport = ActionMailerCloudflare::FakeTransport.new
    @original = [ UserMailer.delivery_method, UserMailer.cloudflare_settings ]
    UserMailer.delivery_method = :cloudflare
    UserMailer.cloudflare_settings = { transport: @transport, account_id: "0123456789abcdef0123456789abcdef", api_token: "test-token" }
  end

  teardown { UserMailer.delivery_method, UserMailer.cloudflare_settings = @original }

  test "a rate-limited welcome is not sent" do
    @transport.answer(status: 429, json: { success: false, errors: [ { code: 10004, message: "rate limited" } ] })

    assert_raises(ActionMailerCloudflare::Unsent) { UserMailer.welcome(users(:one)).deliver_now }
    assert_equal [ users(:one).email ], @transport.sent.sole.json["recipients"]
  end
end
```

A new `FakeTransport` accepts every message. `answer(status:, json:)` or `answer(status:, body:)` sets the response to every later request. `fail_with(error)` makes every later request raise `error`. Each entry in `sent` has the `url`, the `headers`, the raw `body`, and the parsed `json`.

## Why send_raw

Cloudflare's REST API sends mail through `send` or `send_raw`. `send` takes the message as JSON fields: subject, text, HTML, attachments, and an allowlist of custom headers. `send_raw` takes a complete MIME message and the envelope.

ActionMailer has already built a correct MIME message, with multipart alternatives, attachments, inline images, `Reply-To`, and any `List-Unsubscribe` header. Sending it to `send` would mean taking that message apart again, and Cloudflare would drop any header outside its allowlist. `send_raw` sends the bytes ActionMailer produced, unchanged.

The envelope decides who receives the message. The gem reads it from `mail.smtp_envelope_from` and `mail.smtp_envelope_to`, as Mail's own SMTP delivery does. Bcc recipients are in the envelope and absent from the encoded message.

## Why not SMTP on DigitalOcean

DigitalOcean blocks outbound traffic on ports 25, 465, and 587 from Droplets by default. Cloudflare accepts SMTP submission only on port 465, so SMTP to Cloudflare cannot leave a Droplet. The Email Sending API uses HTTPS on port 443, which is open. The same applies to any host that blocks outbound SMTP.

## Develop the gem

Run the suite against the latest supported Rails with `bundle exec rake`. Lint with `bundle exec rubocop`. To run against a specific Rails version, pick its gemfile:

```sh
BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile bundle exec rake
```

## License

MIT. See [LICENSE.txt](LICENSE.txt).
