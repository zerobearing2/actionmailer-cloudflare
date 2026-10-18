module ActionMailerCloudflare
  # Missing or malformed configuration, or a message with no envelope. Nothing was sent.
  class Error < StandardError; end
  # Cloudflare refused this message. Sending it again fails the same way.
  class Rejected < Error; end
  # Cloudflare may have sent it. A retry may succeed, and may deliver a duplicate.
  class Unavailable < Error; end
  # Cloudflare never accepted it, so a retry cannot duplicate it.
  class Unsent < Unavailable; end
end
