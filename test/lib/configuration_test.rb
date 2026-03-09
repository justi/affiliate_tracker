# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < Minitest::Test
  def setup
    @config = AffiliateTracker::Configuration.new
  end

  def test_base_url_from_rails_routes
    assert_equal 'https://test.example.com', @config.base_url
  end

  def test_secret_key_from_rails_key_generator
    key = @config.secret_key
    assert_equal 32, key.bytesize
  end

  def test_can_set_authenticate_dashboard
    auth_proc = -> { redirect_to login_path }
    @config.authenticate_dashboard = auth_proc
    assert_equal auth_proc, @config.authenticate_dashboard
  end

  def test_can_set_after_click
    handler = ->(click) { puts click.id }
    @config.after_click = handler
    assert_equal handler, @config.after_click
  end

  def test_authenticate_dashboard_default_nil
    assert_nil @config.authenticate_dashboard
  end

  def test_after_click_default_nil
    assert_nil @config.after_click
  end

  def test_fallback_url_default_is_root
    assert_equal '/', @config.fallback_url
  end

  def test_resolve_fallback_url_with_string
    @config.fallback_url = '/error'
    assert_equal '/error', @config.resolve_fallback_url(nil)
  end

  def test_resolve_fallback_url_with_proc
    @config.fallback_url = lambda { |payload|
      slug = payload&.dig('shop')
      slug ? "/#{slug}" : '/home'
    }

    # With valid payload containing shop slug
    payload = Base64.urlsafe_encode64({ 'u' => 'https://shop.com', 'shop' => 'my-shop' }.to_json, padding: false)
    assert_equal '/my-shop', @config.resolve_fallback_url(payload)
  end

  def test_resolve_fallback_url_proc_without_shop
    @config.fallback_url = lambda { |payload|
      slug = payload&.dig('shop')
      slug ? "/#{slug}" : '/home'
    }

    # Payload without shop key
    payload = Base64.urlsafe_encode64({ 'u' => 'https://shop.com' }.to_json, padding: false)
    assert_equal '/home', @config.resolve_fallback_url(payload)
  end

  def test_resolve_fallback_url_with_nil_payload
    @config.fallback_url = ->(payload) { payload ? '/found' : '/nope' }
    assert_equal '/nope', @config.resolve_fallback_url(nil)
  end

  def test_resolve_fallback_url_with_corrupt_payload
    @config.fallback_url = ->(payload) { payload ? '/found' : '/nope' }
    assert_equal '/nope', @config.resolve_fallback_url('not-valid-base64!!!')
  end

  def test_resolve_fallback_url_proc_raising_error_falls_back
    @config.fallback_url = ->(_) { raise 'boom' }
    assert_equal '/', @config.resolve_fallback_url(nil)
  end
end

class AffiliateTrackerConfigureTest < Minitest::Test
  def test_configure_yields_configuration
    AffiliateTracker.configure do |config|
      assert_instance_of AffiliateTracker::Configuration, config
    end
  end

  def test_track_url_shorthand
    url = AffiliateTracker.url('https://shop.com', shop_id: 1)
    assert url.start_with?('https://test.example.com/a/')
    assert_match(/\?s=/, url)
  end

  def test_track_url_method
    url = AffiliateTracker.track_url('https://shop.com', { shop_id: 1 })
    assert url.start_with?('https://test.example.com/a/')
  end

  def test_track_url_merges_default_metadata
    AffiliateTracker.configure do |config|
      config.default_metadata = -> { { user_id: 42, campaign: "default" } }
    end

    url = AffiliateTracker.track_url("https://shop.com", shop_id: 1)
    payload, signature = extract_tracking_parts(url)
    result = AffiliateTracker::UrlGenerator.decode(payload, signature)

    assert_equal 42, result[:metadata]["user_id"]
    assert_equal "default", result[:metadata]["campaign"]
    assert_equal 1, result[:metadata]["shop_id"]
  end

  def test_explicit_metadata_overrides_default_metadata
    AffiliateTracker.configure do |config|
      config.default_metadata = -> { { campaign: "default", user_id: 42 } }
    end

    url = AffiliateTracker.track_url("https://shop.com", { campaign: "custom" })
    payload, signature = extract_tracking_parts(url)
    result = AffiliateTracker::UrlGenerator.decode(payload, signature)

    assert_equal "custom", result[:metadata]["campaign"]
    assert_equal 42, result[:metadata]["user_id"]
  end

  def test_non_hash_default_metadata_is_ignored
    AffiliateTracker.configure do |config|
      config.default_metadata = -> { "not-a-hash" }
    end

    url = AffiliateTracker.track_url("https://shop.com")
    payload, signature = extract_tracking_parts(url)
    result = AffiliateTracker::UrlGenerator.decode(payload, signature)

    assert_empty result[:metadata]
  end

  def test_default_metadata_error_does_not_break_url_generation
    AffiliateTracker.configure do |config|
      config.default_metadata = -> { raise "boom" }
    end

    url = AffiliateTracker.track_url("https://shop.com")
    payload, signature = extract_tracking_parts(url)
    result = AffiliateTracker::UrlGenerator.decode(payload, signature)

    assert_equal "https://shop.com", result[:destination_url]
    assert_empty result[:metadata]
  end
end
