module ActionMailerCloudflare
  class Credentials
    ROOT = :cloudflare_email
    FORMATS = { account_id: [ /\A\h{32}\z/, "32 hex characters" ], api_token: [ /\A\S+\z/, "no whitespace" ] }

    attr_reader :account_id, :api_token

    def self.env_name(key) = "#{ROOT}_#{key}".upcase

    # Outside a Rails app, Rails is undefined or (via rails-dom-testing) has no application.
    def self.rails_credentials = (Rails.application&.credentials if defined?(Rails.application)) || {}

    def initialize(settings: {}, env: ENV, store: self.class.rails_credentials)
      @settings = settings
      @env = env
      @store = store
      @account_id = fetch(:account_id)
      @api_token = fetch(:api_token)
    end

    def inspect
      "#<#{self.class.name} account_id=#{account_id.inspect} api_token=[REDACTED]>"
    end

    private
      attr_reader :settings, :env, :store

      def fetch(key)
        format, expected = FORMATS.fetch(key)
        value = lookup(key)
        if value.nil?
          raise Error, "Cloudflare Email #{key} is not set: #{places(key)}"
        elsif value.is_a?(String) && format.match?(value)
          value
        else
          raise Error, "Cloudflare Email #{key} is malformed, expected #{expected}: #{places(key)}"
        end
      end

      def lookup(key)
        settings[key].presence || env[self.class.env_name(key)].presence || store.dig(ROOT, key).presence
      end

      def places(key)
        "set cloudflare_settings[:#{key}], #{self.class.env_name(key)}, or credentials #{ROOT}.#{key}"
      end
  end
end
