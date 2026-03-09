# frozen_string_literal: true

require "test_helper"

class RoutesTest < Minitest::Test
  def setup
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/a/dashboard", to: "affiliate_tracker/dashboard#index"
      get "/a/:payload", to: "affiliate_tracker/clicks#redirect"
    end
  end

  def test_dashboard_path_routes_to_dashboard_controller
    params = @routes.recognize_path("/a/dashboard", method: :get)

    assert_equal "affiliate_tracker/dashboard", params[:controller]
    assert_equal "index", params[:action]
  end

  def test_payload_path_routes_to_clicks_controller
    params = @routes.recognize_path("/a/test-payload", method: :get)

    assert_equal "affiliate_tracker/clicks", params[:controller]
    assert_equal "redirect", params[:action]
    assert_equal "test-payload", params[:payload]
  end
end
