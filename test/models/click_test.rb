# frozen_string_literal: true

require "test_helper"

class ClickTest < ActiveSupport::TestCase
  def test_requires_destination_url
    click = AffiliateTracker::Click.new(clicked_at: Time.current)

    refute click.valid?
    assert_includes click.errors[:destination_url], "can't be blank"
  end

  def test_requires_clicked_at
    click = AffiliateTracker::Click.new(destination_url: "https://shop.com")

    refute click.valid?
    assert_includes click.errors[:clicked_at], "can't be blank"
  end

  def test_domain_returns_host_for_valid_url
    click = AffiliateTracker::Click.new(destination_url: "https://shop.example.com/product")

    assert_equal "shop.example.com", click.domain
  end

  def test_domain_returns_nil_for_invalid_url
    click = AffiliateTracker::Click.new(destination_url: "not a valid url")

    assert_nil click.domain
  end

  def test_today_scope_filters_from_beginning_of_day
    travel_to Time.zone.parse("2026-03-09 15:00:00 UTC") do
      create_click("https://shop.com/today", clicked_at: 2.hours.ago)
      create_click("https://shop.com/yesterday", clicked_at: 1.day.ago)

      assert_equal ["https://shop.com/today"], AffiliateTracker::Click.today.order(:destination_url).pluck(:destination_url)
    end
  end

  def test_this_week_scope_filters_last_seven_days
    travel_to Time.zone.parse("2026-03-09 15:00:00 UTC") do
      create_click("https://shop.com/recent", clicked_at: 3.days.ago)
      create_click("https://shop.com/old", clicked_at: 8.days.ago)

      assert_equal ["https://shop.com/recent"], AffiliateTracker::Click.this_week.order(:destination_url).pluck(:destination_url)
    end
  end

  def test_this_month_scope_filters_last_month
    travel_to Time.zone.parse("2026-03-09 15:00:00 UTC") do
      create_click("https://shop.com/recent", clicked_at: 2.weeks.ago)
      create_click("https://shop.com/old", clicked_at: 6.weeks.ago)

      assert_equal ["https://shop.com/recent"], AffiliateTracker::Click.this_month.order(:destination_url).pluck(:destination_url)
    end
  end

  private

  def create_click(destination_url, clicked_at:)
    AffiliateTracker::Click.create!(
      destination_url: destination_url,
      clicked_at: clicked_at,
      metadata: {}
    )
  end
end
