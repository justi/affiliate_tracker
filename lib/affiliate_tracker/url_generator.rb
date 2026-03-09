# frozen_string_literal: true

require 'base64'
require 'openssl'
require 'json'
require 'active_support/security_utils'

module AffiliateTracker
  class UrlGenerator
    attr_reader :destination_url, :metadata

    def initialize(destination_url, metadata = {})
      @destination_url = destination_url
      @metadata = metadata.transform_keys(&:to_s)
    end

    def generate
      payload = encode_payload
      signature = sign(payload)
      "#{base_url}#{route_path}/#{payload}?s=#{signature}"
    end

    private

    def encode_payload
      data = { u: destination_url }.merge(metadata)
      Base64.urlsafe_encode64(data.to_json, padding: false)
    end

    def sign(payload)
      OpenSSL::HMAC.hexdigest('SHA256', secret_key, payload).first(32)
    end

    def base_url
      AffiliateTracker.configuration.base_url or raise Error, 'base_url not configured'
    end

    def route_path
      '/a'
    end

    def secret_key
      AffiliateTracker.configuration.secret_key or raise Error, 'secret_key not configured'
    end

    class << self
      def decode(payload, signature)
        raise Error, 'Missing payload' if payload.nil? || payload.empty?
        raise Error, 'Missing signature' if signature.nil? || signature.empty?

        expected_sig = OpenSSL::HMAC.hexdigest(
          'SHA256',
          AffiliateTracker.configuration.secret_key,
          payload
        ).first(32)

        raise Error, 'Invalid signature' unless ActiveSupport::SecurityUtils.secure_compare(expected_sig, signature)

        data = JSON.parse(Base64.urlsafe_decode64(payload))
        {
          destination_url: data.delete('u'),
          metadata: data
        }
      end
    end
  end
end
