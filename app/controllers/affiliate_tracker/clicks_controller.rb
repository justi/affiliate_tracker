# frozen_string_literal: true

require 'uri'

module AffiliateTracker
  class ClicksController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:redirect]

    def redirect
      payload = params[:payload]
      signature = params[:s]

      begin
        data = UrlGenerator.decode(payload, signature)
        destination_url = data[:destination_url]
        metadata = data[:metadata]

        # Record the click
        record_click(destination_url, metadata)

        # Normalize URL protocol
        destination_url = "https://#{destination_url}" unless destination_url.match?(%r{\A[a-zA-Z][a-zA-Z0-9+\-.]*://})

        # Build final URL with UTM parameters
        final_url = append_utm_params(destination_url, metadata)

        # Redirect to destination
        redirect_to final_url, allow_other_host: true, status: :moved_permanently
      rescue AffiliateTracker::Error => e
        Rails.logger.warn "[AffiliateTracker] Invalid tracking URL: #{e.message} from #{request.remote_ip}"
        redirect_to AffiliateTracker.configuration.resolve_fallback_url(payload), allow_other_host: true
      end
    end

    private

    def record_click(destination_url, metadata)
      dedup_key = "affiliate_tracker:#{request.remote_ip}:#{destination_url}"

      # Deduplication using Rails.cache (5 seconds window)
      return if Rails.cache.exist?(dedup_key)

      Rails.cache.write(dedup_key, true, expires_in: 5.seconds)

      click = Click.create!(
        destination_url: destination_url,
        ip_address: anonymize_ip(request.remote_ip),
        user_agent: request.user_agent&.truncate(500),
        referer: request.referer&.truncate(500),
        metadata: metadata,
        clicked_at: Time.current
      )

      # Call custom handler if configured
      if (handler = AffiliateTracker.configuration.after_click)
        handler.call(click)
      end
    rescue StandardError => e
      Rails.logger.error "[AffiliateTracker] Failed to record click: #{e.message}"
    end

    def append_utm_params(url, metadata)
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query || '')

      # Add ref and UTM params (metadata overrides defaults)
      config = AffiliateTracker.configuration
      tracking_params = {
        'ref' => config.ref_param,
        'utm_source' => metadata['utm_source'] || config.utm_source,
        'utm_medium' => metadata['utm_medium'] || config.utm_medium,
        'utm_campaign' => metadata['campaign'],
        'utm_content' => metadata['shop']
      }.compact

      # Merge with existing params (don't overwrite if already present)
      existing_keys = params.map(&:first)
      tracking_params.each do |key, value|
        params << [key, value] unless existing_keys.include?(key)
      end

      uri.query = URI.encode_www_form(params) if params.any?
      uri.to_s
    rescue URI::InvalidURIError
      url
    end

    def anonymize_ip(ip)
      return nil if ip.blank?

      parts = ip.split('.')
      return ip unless parts.size == 4

      parts[3] = '0'
      parts.join('.')
    end
  end
end
