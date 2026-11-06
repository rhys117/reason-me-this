require 'json'
require 'openssl'

module ReasonMeThis
  # Checks a delivery the service posted to a webhook: the RMT-Signature header is t=<unix time>,v1=<hex
  # HMAC-SHA256 of "<t>.<body>" with the subscription's secret>. A delivery signed more than tolerance seconds
  # from now is refused, so a captured one cannot be replayed later.
  module Webhook
    TOLERANCE = 300

    module_function

    def verify(body, signature, secret, now: Time.now, tolerance: TOLERANCE)
      delivered = payload(body, signature, secret, now:, tolerance:)
      Event.new(name: delivered[:event].to_sym, data: delivered.fetch(:data, {}))
    end

    def payload(body, signature, secret, now: Time.now, tolerance: TOLERANCE)
      at, given = signature.to_s.split(',').to_h { |part| part.split('=', 2) }.values_at('t', 'v1')
      raise InvalidSignature.new('the delivery is not signed') unless at && given
      raise InvalidSignature.new("the delivery was signed more than #{tolerance} seconds from now") if (now.to_i - at.to_i).abs > tolerance
      expected = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{at}.#{body}")
      raise InvalidSignature.new('the signature does not match') unless OpenSSL.secure_compare(expected, given)

      Values.read(JSON.parse(body, symbolize_names: true))
    end
  end
end
