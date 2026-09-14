require "test_helper"

class WebsiteNormalizerTest < ActiveSupport::TestCase
  test "adds https and normalizes host path and default port" do
    result = WebsiteNormalizer.call(url: "WWW.Example.com:443/")

    assert_nil result.error
    assert_equal "https://www.example.com", result.normalized_url
    assert_equal "www.example.com", result.normalized_host
  end

  test "preserves meaningful path and query while rejecting credentials" do
    kept = WebsiteNormalizer.call(url: "https://example.com/path?q=1#frag")
    assert_equal "https://example.com/path?q=1", kept.normalized_url

    bad = WebsiteNormalizer.call(url: "https://user:pass@example.com")
    assert_equal "Website URL cannot contain credentials.", bad.error
  end

  test "www host is not collapsed to apex" do
    www = WebsiteNormalizer.call(url: "https://www.example.com")
    apex = WebsiteNormalizer.call(url: "https://example.com")

    assert_equal "www.example.com", www.normalized_host
    assert_equal "example.com", apex.normalized_host
    assert_not_equal www.normalized_host, apex.normalized_host
  end
end
