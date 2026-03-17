# frozen_string_literal: true

require 'test_helper'

class UrlGeneratorTest < Minitest::Test
  def setup
    @destination = 'https://shop.example.com/product/123'
    @metadata = { shop_id: 1, promotion_id: 42, campaign: 'email' }
  end

  def test_generates_url_with_base_url
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    assert url.start_with?('https://test.example.com/a/')
  end

  def test_generates_url_with_signature
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    assert_match(/\?s=[a-f0-9]{32}$/, url)
  end

  def test_generates_url_with_payload
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    # Extract payload between /a/ and ?s=
    payload = url.match(%r{/a/([^?]+)\?})[1]
    assert payload.length > 10
  end

  def test_includes_metadata_in_payload
    url = AffiliateTracker::UrlGenerator.new(@destination, @metadata).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    decoded = JSON.parse(Base64.urlsafe_decode64(payload))

    assert_equal @destination, decoded['u']
    assert_equal 1, decoded['shop_id']
    assert_equal 42, decoded['promotion_id']
    assert_equal 'email', decoded['campaign']
  end

  def test_decode_returns_destination_url
    url = AffiliateTracker::UrlGenerator.new(@destination, @metadata).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal @destination, result[:destination_url]
  end

  def test_decode_returns_metadata
    url = AffiliateTracker::UrlGenerator.new(@destination, @metadata).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 1, result[:metadata]['shop_id']
    assert_equal 42, result[:metadata]['promotion_id']
  end

  def test_decode_raises_on_invalid_signature
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]

    assert_raises(AffiliateTracker::Error) do
      AffiliateTracker::UrlGenerator.decode(payload, 'invalidsignature')
    end
  end

  def test_decode_raises_on_tampered_payload
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]
    tampered_payload = Base64.urlsafe_encode64({ u: 'https://evil.com' }.to_json, padding: false)

    assert_raises(AffiliateTracker::Error) do
      AffiliateTracker::UrlGenerator.decode(tampered_payload, signature)
    end
  end

  def test_different_destinations_produce_different_signatures
    url1 = AffiliateTracker::UrlGenerator.new('https://shop1.com').generate
    url2 = AffiliateTracker::UrlGenerator.new('https://shop2.com').generate

    sig1 = url1.match(/\?s=([a-f0-9]+)$/)[1]
    sig2 = url2.match(/\?s=([a-f0-9]+)$/)[1]

    assert sig1 != sig2, 'Expected different signatures for different URLs'
  end

  def test_same_input_produces_same_url
    url1 = AffiliateTracker::UrlGenerator.new(@destination, @metadata).generate
    url2 = AffiliateTracker::UrlGenerator.new(@destination, @metadata).generate

    assert_equal url1, url2
  end

  def test_handles_special_characters_in_url
    special_url = 'https://shop.com/search?q=test&category=shoes'
    url = AffiliateTracker::UrlGenerator.new(special_url).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal special_url, result[:destination_url]
  end

  def test_handles_unicode_in_metadata
    unicode_metadata = { campaign: 'lato_2024_żółć' }
    url = AffiliateTracker::UrlGenerator.new(@destination, unicode_metadata).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 'lato_2024_żółć', result[:metadata]['campaign']
  end

  def test_normalizes_url_without_protocol
    url = AffiliateTracker::UrlGenerator.new('shop.example.com/sale').generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 'https://shop.example.com/sale', result[:destination_url]
  end

  def test_preserves_http_url
    url = AffiliateTracker::UrlGenerator.new('http://shop.example.com').generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 'http://shop.example.com', result[:destination_url]
  end

  def test_preserves_https_url
    url = AffiliateTracker::UrlGenerator.new('https://shop.example.com').generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 'https://shop.example.com', result[:destination_url]
  end

  def test_preserves_ftp_protocol
    gen = AffiliateTracker::UrlGenerator.new('ftp://files.example.com/data')
    url = gen.generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 'ftp://files.example.com/data', result[:destination_url]
  end

  def test_normalizes_url_with_port
    gen = AffiliateTracker::UrlGenerator.new('shop.example.com:8080/product')
    url = gen.generate
    payload = url.match(%r{/a/([^?]+)\?})[1]
    signature = url.match(/\?s=([a-f0-9]+)$/)[1]

    result = AffiliateTracker::UrlGenerator.decode(payload, signature)
    assert_equal 'https://shop.example.com:8080/product', result[:destination_url]
  end

  def test_normalize_blank_url_returns_blank
    gen = AffiliateTracker::UrlGenerator.new('')
    assert_equal '', gen.destination_url
  end

  def test_normalize_nil_url_returns_nil
    gen = AffiliateTracker::UrlGenerator.new(nil)
    assert_nil gen.destination_url
  end

  def test_decode_raises_on_nil_payload
    assert_raises(AffiliateTracker::Error) do
      AffiliateTracker::UrlGenerator.decode(nil, 'somesig')
    end
  end

  def test_decode_raises_on_empty_payload
    assert_raises(AffiliateTracker::Error) do
      AffiliateTracker::UrlGenerator.decode('', 'somesig')
    end
  end

  def test_decode_raises_on_nil_signature
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]

    assert_raises(AffiliateTracker::Error) do
      AffiliateTracker::UrlGenerator.decode(payload, nil)
    end
  end

  def test_decode_raises_on_empty_signature
    url = AffiliateTracker::UrlGenerator.new(@destination).generate
    payload = url.match(%r{/a/([^?]+)\?})[1]

    assert_raises(AffiliateTracker::Error) do
      AffiliateTracker::UrlGenerator.decode(payload, '')
    end
  end
end
