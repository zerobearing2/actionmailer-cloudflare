module ActionMailerCloudflare
  class DeliveryMethod
    ENDPOINT = "https://api.cloudflare.com/client/v4/accounts/%<account_id>s/email/sending/send_raw"

    attr_accessor :settings

    # Mail builds one of these for every message, previews included, so this
    # must not read credentials.
    def initialize(settings = {})
      @settings = settings
    end

    def deliver!(mail)
      payload = payload(mail)
      credentials = Credentials.new(settings: settings.slice(:account_id, :api_token))
      transport.post(url(credentials), headers: headers(credentials), body: payload).verify!
    end

    private
      def transport = settings.fetch(:transport) { HttpTransport.new }

      def url(credentials) = format(ENDPOINT, account_id: credentials.account_id)

      def headers(credentials) = { "Authorization" => "Bearer #{credentials.api_token}", "Content-Type" => "application/json" }

      # The envelope, not the headers, decides who receives it: Bcc is in
      # recipients and absent from the encoded message.
      def payload(mail)
        JSON.generate(from: envelope_from(mail), recipients: envelope_to(mail), mime_message: mail.encoded)
      end

      def envelope_from(mail)
        mail.smtp_envelope_from.presence || raise(Error, "Cloudflare Email needs a sender: the message has no From, Sender, or Return-Path")
      end

      def envelope_to(mail)
        mail.smtp_envelope_to.presence || raise(Error, "Cloudflare Email needs recipients: the message has no To, Cc, or Bcc")
      end
  end
end
