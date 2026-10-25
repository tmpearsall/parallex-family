# Public price list for the commercial instance. Each paid plan's button is a Stripe Payment Link set in an
# environment variable (STRIPE_LINK_COMMITTEE_MONTH, _COMMITTEE_YEAR, _ORGANIZATION_MONTH, _EVENT_PASS); until one
# is set, that plan's button asks the person to get in touch instead.
class PricingController < ApplicationController
  skip_before_action :authenticate_user!

  PLANS = [
    { key: "free", name: "Free", price: "$0", per: "", pick: false,
      points: [ "1 organization", "Up to 25 invitees", "1 event at a time", "Date voting, RSVPs, task list, forum" ] },
    { key: "committee", name: "Committee", price: "$19", per: "/month", alt: "or $149 a year", pick: true,
      points: [ "Unlimited events", "Up to 250 invitees", "Email invitations and reminders", "Calendar feeds for every member" ],
      links: { "month" => "STRIPE_LINK_COMMITTEE_MONTH", "year" => "STRIPE_LINK_COMMITTEE_YEAR" } },
    { key: "multi", name: "Multi-committee", price: "$49", per: "/month", pick: false,
      points: [ "Several committees under one organization account", "More invitees", "Priority support" ],
      links: { "month" => "STRIPE_LINK_MULTI_MONTH" } },
    { key: "event_pass", name: "Event pass", price: "$29", per: " once", pick: false,
      points: [ "One event, planned start to finish", "Everything in Committee for that event", "No subscription" ],
      links: { "once" => "STRIPE_LINK_EVENT_PASS" } }
  ].freeze

  helper_method :link_for
  def show; end
  def indexable? = true
  def link_for(plan, term) = ENV[plan[:links]&.fetch(term, nil).to_s].presence
end
