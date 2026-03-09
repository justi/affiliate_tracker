# frozen_string_literal: true

require "test_helper"

class DashboardControllerTest < ActionController::TestCase
  tests AffiliateTracker::DashboardController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/a/dashboard", to: "affiliate_tracker/dashboard#index"
    end
  end

  def test_index_renders_successfully_without_auth_hook
    get :index

    assert_response :success
    assert_includes @response.body, "Affiliate Tracker"
  end

  def test_index_executes_authenticate_dashboard_hook
    called = false

    AffiliateTracker.configure do |config|
      config.authenticate_dashboard = -> { called = true }
    end

    get :index

    assert called
    assert_response :success
  end

  def test_index_allows_auth_hook_to_redirect
    AffiliateTracker.configure do |config|
      config.authenticate_dashboard = -> { redirect_to "/login" }
    end

    get :index

    assert_redirected_to "/login"
  end

  def test_index_assigns_stats_recent_clicks_and_top_destinations
    travel_to Time.zone.parse("2026-03-09 15:00:00 UTC") do
      create_click("https://shop.com/a", clicked_at: 2.hours.ago, metadata: { "campaign" => "today" })
      create_click("https://shop.com/a", clicked_at: 2.days.ago, metadata: { "campaign" => "week" })
      create_click("https://shop.com/b", clicked_at: 10.days.ago, metadata: { "campaign" => "older" })
      latest = create_click("https://shop.com/c", clicked_at: 30.minutes.ago, metadata: { "campaign" => "latest" })

      get :index

      stats = @controller.instance_variable_get(:@stats)
      recent_clicks = @controller.instance_variable_get(:@recent_clicks)
      top_destinations = @controller.instance_variable_get(:@top_destinations)

      assert_response :success
      assert_equal 4, stats[:total_clicks]
      assert_equal 2, stats[:today_clicks]
      assert_equal 3, stats[:week_clicks]
      assert_equal 3, stats[:unique_destinations]
      assert_equal latest, recent_clicks.first
      assert_equal 2, top_destinations["https://shop.com/a"]
      assert_includes @response.body, "https://shop.com/a"
      assert_includes @response.body, latest.clicked_at.strftime("%Y-%m-%d %H:%M")
    end
  end

  private

  def create_click(destination_url, clicked_at:, metadata:)
    AffiliateTracker::Click.create!(
      destination_url: destination_url,
      clicked_at: clicked_at,
      metadata: metadata
    )
  end
end
