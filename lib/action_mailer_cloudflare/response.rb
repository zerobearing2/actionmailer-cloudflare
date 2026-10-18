module ActionMailerCloudflare
  class Response
    attr_reader :status, :body

    def initialize(status:, body:)
      @status = status
      @body = body
    end

    def verify!
      case status
      when 200..299 then verify_accepted!
      when 429 then raise Unsent, failure("not sent")
      when 400..499 then raise Rejected, failure("rejected")
      else raise Unavailable, failure("outcome unknown")
      end
    end

    private
      def verify_accepted!
        if json["success"] != true
          raise Unavailable, failure("outcome unknown")
        elsif permanent_bounces.any?
          raise Rejected, "Cloudflare Email HTTP #{status}: #{permanent_bounces.size} #{permanent_bounces.one? ? "recipient" : "recipients"} bounced permanently"
        else
          self
        end
      end

      def permanent_bounces
        result = json["result"]
        result.is_a?(Hash) ? Array.wrap(result["permanent_bounces"]) : []
      end

      def failure(outcome)
        [ "Cloudflare Email HTTP #{status}, #{outcome}", error_summary.presence ].compact.join(": ")
      end

      def error_summary
        Array.wrap(json["errors"]).filter_map { |error| "#{error["code"]} #{error["message"]}" if error.is_a?(Hash) }.join("; ")
      end

      def json
        @json ||= parse
      end

      def parse
        parsed = JSON.parse(body)
        parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        {}
      end
  end
end
