# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] ||= "sqlite3::memory:"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_support/testing/autorun"
require "logger"
require "uri"

class AffiliateTrackerTestApp < Rails::Application
  config.root = File.expand_path("..", __dir__)
  config.eager_load = false
  config.secret_key_base = "test_secret_key_base_12345678901234567890"
  config.hosts << "www.example.com"
  config.hosts << "test.example.com"
  config.logger = Logger.new($stdout, level: Logger::WARN)
  config.cache_store = :memory_store
  config.action_mailer.default_url_options = { host: "test.example.com", protocol: "https" }

  if config.active_record.respond_to?(:sqlite3_adapter_strict_strings_by_default=)
    config.active_record.sqlite3_adapter_strict_strings_by_default = false
  end
end

require "affiliate_tracker"

AffiliateTrackerTestApp.initialize!
Rails.application.routes_reloader.loaded = true

Rails.application.routes.default_url_options[:host] = "test.example.com"
Rails.application.routes.default_url_options[:protocol] = "https"

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :affiliate_tracker_clicks, force: true do |t|
    t.string :destination_url, null: false
    t.string :ip_address
    t.string :user_agent, limit: 500
    t.string :referer, limit: 500
    t.json :metadata
    t.datetime :clicked_at, null: false
    t.timestamps null: false
  end
end
ActiveRecord::Base.logger = nil

require "rails/test_help"

module TrackingUrlHelpers
  def extract_tracking_parts(url)
    uri = URI.parse(url)
    payload = uri.path.split("/").last
    signature = Rack::Utils.parse_query(uri.query).fetch("s")

    [payload, signature]
  end
end

class ActiveSupport::TestCase
  include TrackingUrlHelpers

  setup do
    Rails.cache.clear
    AffiliateTracker.configuration = AffiliateTracker::Configuration.new
    AffiliateTracker::Click.delete_all
  end
end

class Minitest::Test
  include TrackingUrlHelpers
end

class ActionDispatch::IntegrationTest
  include TrackingUrlHelpers

  setup do
    Rails.cache.clear
    AffiliateTracker.configuration = AffiliateTracker::Configuration.new
    AffiliateTracker::Click.delete_all
  end

  private

  def get_tracking_url(url, headers: {})
    uri = URI.parse(url)
    get uri.request_uri, headers: headers
  end
end
