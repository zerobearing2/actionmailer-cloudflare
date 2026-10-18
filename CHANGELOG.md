# Changelog

## 0.1.0 (2026-10-18)

First release, extracted from juniperdoors.com.

- Adds the `:cloudflare` ActionMailer delivery method, which posts the encoded message to Cloudflare's `send_raw` endpoint.
- Reads the account ID and the API token at delivery time, from `cloudflare_settings`, then `CLOUDFLARE_EMAIL_ACCOUNT_ID` and `CLOUDFLARE_EMAIL_API_TOKEN`, then Rails credentials under `cloudflare_email`.
- Raises `Error`, `Rejected`, `Unavailable`, and `Unsent`, split by whether a retry is safe.
- Ships `ActionMailerCloudflare::FakeTransport` for tests, behind `require "action_mailer_cloudflare/fake_transport"`.
