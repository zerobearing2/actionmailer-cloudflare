require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/array/wrap"
require "json"
require_relative "action_mailer_cloudflare/version"
require_relative "action_mailer_cloudflare/error"
require_relative "action_mailer_cloudflare/credentials"
require_relative "action_mailer_cloudflare/response"
require_relative "action_mailer_cloudflare/http_transport"
require_relative "action_mailer_cloudflare/delivery_method"

# Bundler.require loads this before Rails runs its initializers, so this hook runs
# ahead of action_mailer.set_configs' and cloudflare_settings= exists when it assigns config.
ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :cloudflare, ActionMailerCloudflare::DeliveryMethod
end
