# frozen_string_literal: true

require "test_helper"

class ClicksControllerTest < ActionController::TestCase
  tests AffiliateTracker::ClicksController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/a/:payload", to: "affiliate_tracker/clicks#redirect"
      get "/a/dashboard", to: "affiliate_tracker/dashboard#index"
    end
  end

  def test_redirect_records_click_and_appends_tracking_params
    payload, signature = extract_tracking_parts(
      AffiliateTracker.url(
        "https://shop.com/product?color=red",
        campaign: "summer_sale",
        shop: "modago"
      )
    )

    with_request_metadata(
      remote_addr: "203.0.113.42",
      user_agent: "Mozilla/5.0",
      referer: "https://newsletter.example.com/issues/1"
    ) do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_redirected_to(
      "https://shop.com/product?color=red&utm_source=affiliate&utm_medium=referral&utm_campaign=summer_sale&utm_content=modago"
    )

    click = AffiliateTracker::Click.order(:created_at).last
    assert_equal "https://shop.com/product?color=red", click.destination_url
    assert_equal "203.0.113.0", click.ip_address
    assert_equal "Mozilla/5.0", click.user_agent
    assert_equal "https://newsletter.example.com/issues/1", click.referer
    assert_equal(
      {
        "campaign" => "summer_sale",
        "shop" => "modago"
      },
      click.metadata
    )
  end

  def test_redirect_preserves_existing_tracking_params
    AffiliateTracker.configure do |config|
      config.ref_param = "partnerJan"
    end

    payload, signature = extract_tracking_parts(
      AffiliateTracker.url(
        "https://shop.com/product?utm_source=google&ref=existing",
        campaign: "spring"
      )
    )

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_redirected_to(
      "https://shop.com/product?utm_source=google&ref=existing&utm_medium=referral&utm_campaign=spring"
    )
  end

  def test_invalid_signature_redirects_to_static_fallback
    AffiliateTracker.configure do |config|
      config.fallback_url = "/oops"
    end

    payload, = extract_tracking_parts(AffiliateTracker.url("https://shop.com", shop: "modago"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: "invalid" }
    end

    assert_redirected_to "/oops"
    assert_equal 0, AffiliateTracker::Click.count
  end

  def test_invalid_signature_redirects_to_proc_fallback_using_untrusted_payload
    AffiliateTracker.configure do |config|
      config.fallback_url = lambda { |payload|
        slug = payload&.dig("shop")
        slug.present? ? "/shops/#{slug}" : "/"
      }
    end

    payload, = extract_tracking_parts(AffiliateTracker.url("https://shop.com", shop: "modago"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: "invalid" }
    end

    assert_redirected_to "/shops/modago"
  end

  def test_missing_signature_redirects_to_fallback
    AffiliateTracker.configure do |config|
      config.fallback_url = "/missing-signature"
    end

    payload, = extract_tracking_parts(AffiliateTracker.url("https://shop.com", shop: "modago"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload }
    end

    assert_redirected_to "/missing-signature"
    assert_equal 0, AffiliateTracker::Click.count
  end

  def test_corrupt_payload_uses_proc_fallback_with_nil_payload
    AffiliateTracker.configure do |config|
      config.fallback_url = ->(payload) { payload.nil? ? "/fallback-home" : "/unexpected" }
    end

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: "not-valid-base64!!!", s: "invalid" }
    end

    assert_redirected_to "/fallback-home"
  end

  def test_invalid_destination_uri_falls_back_to_original_destination
    payload = Base64.urlsafe_encode64({ u: "http://bad url.test/path with spaces" }.to_json, padding: false)
    signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      AffiliateTracker.configuration.secret_key,
      payload
    ).first(32)

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_redirected_to "http://bad url.test/path with spaces"
    assert_equal "http://bad url.test/path with spaces", AffiliateTracker::Click.last.destination_url
  end

  def test_redirect_adds_ref_param_and_allows_metadata_to_override_utm_defaults
    AffiliateTracker.configure do |config|
      config.ref_param = "partnerJan"
    end

    payload, signature = extract_tracking_parts(
      AffiliateTracker.url(
        "https://shop.com/product",
        utm_source: "newsletter",
        utm_medium: "email",
        campaign: "launch"
      )
    )

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_redirected_to(
      "https://shop.com/product?ref=partnerJan&utm_source=newsletter&utm_medium=email&utm_campaign=launch"
    )
  end

  def test_duplicate_click_within_window_is_not_recorded_twice
    payload, signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product", campaign: "flash"))

    2.times do
      with_request_metadata(remote_addr: "203.0.113.42") do
        get :redirect, params: { payload: payload, s: signature }
      end

      assert_redirected_to "https://shop.com/product?utm_source=affiliate&utm_medium=referral&utm_campaign=flash"
    end

    assert_equal 1, AffiliateTracker::Click.count
  end

  def test_different_ip_records_separate_clicks
    payload, signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product", campaign: "flash"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: signature }
    end

    with_request_metadata(remote_addr: "203.0.113.43") do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_equal 2, AffiliateTracker::Click.count
  end

  def test_different_destination_records_separate_clicks
    first_payload, first_signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product-a", campaign: "flash"))
    second_payload, second_signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product-b", campaign: "flash"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: first_payload, s: first_signature }
    end

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: second_payload, s: second_signature }
    end

    assert_equal 2, AffiliateTracker::Click.count
  end

  def test_after_click_receives_created_click
    received_click = nil

    AffiliateTracker.configure do |config|
      config.after_click = ->(click) { received_click = click }
    end

    payload, signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product", campaign: "flash"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_instance_of AffiliateTracker::Click, received_click
    assert_equal AffiliateTracker::Click.last, received_click
  end

  def test_after_click_errors_do_not_break_redirect
    AffiliateTracker.configure do |config|
      config.after_click = ->(_) { raise "boom" }
    end

    payload, signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product", campaign: "flash"))

    with_request_metadata(remote_addr: "203.0.113.42") do
      get :redirect, params: { payload: payload, s: signature }
    end

    assert_redirected_to "https://shop.com/product?utm_source=affiliate&utm_medium=referral&utm_campaign=flash"
    assert_equal 1, AffiliateTracker::Click.count
  end

  def test_user_agent_and_referer_are_truncated
    long_user_agent = "u" * 600
    long_referer = "https://newsletter.example.com/" + ("r" * 600)
    payload, signature = extract_tracking_parts(AffiliateTracker.url("https://shop.com/product"))

    with_request_metadata(
      remote_addr: "203.0.113.42",
      user_agent: long_user_agent,
      referer: long_referer
    ) do
      get :redirect, params: { payload: payload, s: signature }
    end

    click = AffiliateTracker::Click.last
    assert_equal 500, click.user_agent.length
    assert_equal 500, click.referer.length
  end

  private

  def with_request_metadata(remote_addr:, user_agent: nil, referer: nil)
    previous_env = @request.env.slice("REMOTE_ADDR", "HTTP_USER_AGENT", "HTTP_REFERER")

    @request.env["REMOTE_ADDR"] = remote_addr
    @request.env["HTTP_USER_AGENT"] = user_agent
    @request.env["HTTP_REFERER"] = referer

    yield
  ensure
    @request.env["REMOTE_ADDR"] = previous_env["REMOTE_ADDR"]
    @request.env["HTTP_USER_AGENT"] = previous_env["HTTP_USER_AGENT"]
    @request.env["HTTP_REFERER"] = previous_env["HTTP_REFERER"]
  end
end
