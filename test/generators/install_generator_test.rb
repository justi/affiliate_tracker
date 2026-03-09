# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/affiliate_tracker/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests AffiliateTracker::Generators::InstallGenerator
  destination File.expand_path("../tmp/install_generator", __dir__)

  setup :prepare_destination
  setup :create_host_app_skeleton

  def test_generator_creates_initializer_migration_and_mounts_engine
    generator.copy_migration
    generator.create_initializer
    generator.mount_engine

    assert_initializer "affiliate_tracker.rb" do |content|
      assert_match(/AffiliateTracker\.configure do \|config\|/, content)
      assert_match(/config\.fallback_url = "\/"/, content)
    end

    assert_migration "db/migrate/create_affiliate_tracker_clicks.rb" do |content|
      assert_match(/create_table :affiliate_tracker_clicks/, content)
      assert_match(/add_index :affiliate_tracker_clicks, :destination_url/, content)
      assert_match(/add_index :affiliate_tracker_clicks, :clicked_at/, content)
    end

    assert_file "config/routes.rb" do |content|
      assert_match(/mount AffiliateTracker::Engine, at: "\/a"/, content)
    end
  end

  def test_mount_engine_is_idempotent
    generator.mount_engine
    generator.mount_engine

    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan('mount AffiliateTracker::Engine, at: "/a"').size
    end
  end

  private

  def create_host_app_skeleton
    FileUtils.mkdir_p(File.join(destination_root, "config", "initializers"))
    FileUtils.mkdir_p(File.join(destination_root, "db", "migrate"))

    File.write(
      File.join(destination_root, "config", "routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )
  end
end
