# AffiliateTracker

Click tracking for affiliates working with small e-commerce shops. Track your clicks, add UTM params, prove your value.

## Who is this for?

**You're an affiliate/influencer** who promotes products from small shops (Shoplo, Shoper, WooCommerce, IdoSell, etc.) that **don't have their own affiliate system**.

You send traffic via newsletters, blogs, or social media — but you have no way to prove how many clicks you actually sent. The shop owner sees some visits in Google Analytics, but can't tell which came from you.

**This gem solves that:**
- You track every click on your side (proof for negotiations)
- Links automatically include UTM parameters (shop sees your traffic in their GA)
- Optional `ref=` parameter for shops that support simple referral tracking

**Not for:** Amazon, eBay, or platforms with existing affiliate programs (they have their own tracking and often prohibit link masking).

## Problem

```
You: "I sent you 500 clicks this month"
Shop: "Google Analytics shows only 200 visits"
You: "..."
```

## Solution

```
Your email → User clicks → AffiliateTracker counts → Redirect with UTM → Shop sees source
                              ↓
                    You have proof: 500 clicks
                    Shop sees: utm_source=yourname
```

## Features

- Click tracking with metadata (shop, campaign, etc.)
- Automatic UTM parameter injection
- Click deduplication (same IP + URL within 5s counted once)
- Built-in dashboard
- Rails 8+ / zero configuration

## Installation

```ruby
gem "affiliate_tracker"
```

Or, for the latest development version:

```ruby
gem "affiliate_tracker", git: "https://github.com/justi-blue/affiliate_tracker"
```

```bash
rails generate affiliate_tracker:install
rails db:migrate
```

## Usage

### affiliate_link helper

```erb
<%# Simple link %>
<%= affiliate_link "https://modago.pl/sukienka", "Zobacz sukienkę" %>

<%# With metadata %>
<%= affiliate_link "https://modago.pl/sukienka", "Zobacz sukienkę",
      shop: "modago",
      campaign: "homepage" %>

<%# With CSS classes %>
<%= affiliate_link "https://modago.pl/sukienka", "Zobacz",
      shop: "modago",
      class: "btn btn-primary" %>

<%# Block syntax %>
<%= affiliate_link "https://modago.pl/sukienka", shop: "modago" do %>
  <img src="photo.jpg"> Zobacz ofertę
<% end %>
```

**Generates:**
```html
<a href="https://yourapp.com/a/eyJ...?s=abc" target="_blank" rel="noopener">
  Zobacz sukienkę
</a>
```

### affiliate_url helper (URL only)

```erb
<a href="<%= affiliate_url 'https://modago.pl/sukienka', shop: 'modago' %>">
  Custom link
</a>
```

### User Tracking

Track which user clicked a link by passing `user_id`:

```erb
<%# On web pages - use Current.user %>
<%= affiliate_link "https://shop.com/product", "Buy Now",
      user_id: Current.user&.id,
      campaign: "homepage" %>

<%# In mailers - pass user explicitly (Current.user not available in background jobs) %>
<%= affiliate_link "https://shop.com/product", "View Deal",
      user_id: @user.id,
      shop_id: @shop.id,
      campaign: "daily_digest" %>
```

Common tracking parameters:
- `user_id` - User who clicked (for attribution)
- `shop_id` - Shop identifier
- `promotion_id` - Specific promotion
- `campaign` - Campaign name (e.g., "daily_digest", "homepage")

### In Mailers

```erb
<%# app/views/digest_mailer/weekly.html.erb %>
<% @promotions.each do |promo| %>
  <%= affiliate_link promo.shop.website_url, "Zobacz promocję",
        user_id: @user.id,
        shop_id: promo.shop.id,
        promotion_id: promo.id,
        campaign: "weekly_digest" %>
<% end %>
```

### Real Example: Shoplo Store

```erb
<%# Just the product URL - ref param added automatically from config %>
<%= affiliate_link "https://demo.shoplo.com/koszulka-bawelniana",
      "Zobacz koszulkę",
      shop: "shoplo-demo",
      campaign: "styczen2025" %>
```

**User clicks → AffiliateTracker counts → Redirects to:**
```
https://demo.shoplo.com/koszulka-bawelniana?ref=partnerJan&utm_source=smartoffers&utm_medium=email&utm_campaign=styczen2025&utm_content=shoplo-demo
```

The shop sees:
- `ref=partnerJan` - from `config.ref_param` (automatic)
- UTM params - in Google Analytics

### Result

1. Generates: `https://yourapp.com/a/eyJ...?s=abc`
2. On click, redirects to: `https://modago.pl/sukienka?utm_source=smartoffers&utm_medium=email&utm_campaign=weekly_digest&utm_content=modago`

### Configuration

```ruby
# config/initializers/affiliate_tracker.rb
AffiliateTracker.configure do |config|
  # Your brand name (appears in utm_source)
  config.utm_source = "smartoffers"

  # Default medium
  config.utm_medium = "email"

  # Referral param (adds ?ref=partnerJan to all links)
  config.ref_param = "partnerJan"

  # Dashboard auth
  config.authenticate_dashboard = -> {
    redirect_to main_app.login_path unless current_user&.admin?
  }
end
```

### Tracking Parameters

| Parameter | Source | Example |
|-----------|--------|---------|
| `ref` | `config.ref_param` | `partnerJan` |
| `utm_source` | `config.utm_source` | `smartoffers` |
| `utm_medium` | `config.utm_medium` | `email` |
| `utm_campaign` | `campaign:` in helper | `weekly_digest` |
| `utm_content` | `shop:` in helper | `modago` |

Override defaults per-link:

```erb
<%= affiliate_url "https://shop.com",
      utm_source: "newsletter",
      utm_medium: "email",
      campaign: "black_friday" %>
```

## Dashboard

Access at `/a/dashboard`

Shows:
- Total clicks
- Clicks today/this week
- Top destinations (shops)
- Recent clicks with metadata

## Security

- Links are signed with **HMAC-SHA256** (128-bit truncated signature per RFC 2104)
- Signature verification uses constant-time comparison (`ActiveSupport::SecurityUtils`)
- Invalid or missing signatures result in a **302 redirect** to a configurable fallback URL (default: `/`)
- Payload is Base64-encoded JSON (not encrypted) — metadata is readable but tamper-proof

### Fallback URL

When a user visits a link with an invalid or missing signature (e.g., bots stripping query params), the gem redirects instead of returning an error:

```ruby
AffiliateTracker.configure do |config|
  # Static URL (default)
  config.fallback_url = "/"

  # Dynamic — receives decoded payload Hash (unverified, treat as untrusted)
  config.fallback_url = ->(payload) {
    slug = payload&.dig("shop")
    slug.present? ? "/shops/#{slug}" : "/"
  }
end
```

## For Shop Owners

Tell your partner shops:
> "All my links include UTM parameters. Check Google Analytics → Acquisition → Traffic Sources → filter by `utm_source=yourname`"

## License

MIT
