require "test_helper"

class PricingTest < ActionDispatch::IntegrationTest
  test "the price list is public and indexable" do
    get "/pricing"
    assert_response :success
    assert_includes response.body, "Committee"
    assert_match(/index/, response.headers["X-Robots-Tag"])
    assert_no_match(/noindex/, response.headers["X-Robots-Tag"])
  end

  test "a plan with a Stripe link shows a subscribe button, otherwise get in touch" do
    get "/pricing"
    assert_includes response.body, "Get in touch"
    ENV["STRIPE_LINK_COMMITTEE_MONTH"] = "https://buy.stripe.com/test_abc"
    get "/pricing"
    assert_includes response.body, "https://buy.stripe.com/test_abc"
  ensure
    ENV.delete("STRIPE_LINK_COMMITTEE_MONTH")
  end
end
