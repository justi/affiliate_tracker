# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def test_action_view_context_includes_affiliate_helpers
    view_context = ActionView::Base.with_empty_template_cache.with_view_paths([])

    url = view_context.affiliate_url("https://shop.com", campaign: "view")

    assert view_context.respond_to?(:affiliate_url)
    assert view_context.respond_to?(:affiliate_link)
    assert_match(%r{\Ahttps://test\.example\.com/a/}, url)
  end

  def test_mailer_templates_can_use_affiliate_helpers
    mailer_class = Class.new(ActionMailer::Base) do
      default from: "from@example.com"

      def sample
        mail(to: "to@example.com", subject: "Hi") do |format|
          format.html do
            render inline: '<%= affiliate_url("https://shop.com", campaign: "mail") %>'
          end
        end
      end
    end

    body = mailer_class.sample.body.encoded

    assert_match(%r{\Ahttps://test\.example\.com/a/}, body)
    payload, signature = extract_tracking_parts(body)
    result = AffiliateTracker::UrlGenerator.decode(payload, signature)

    assert_equal "https://shop.com", result[:destination_url]
    assert_equal "mail", result[:metadata]["campaign"]
  end
end
