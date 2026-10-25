# One codebase, two ways to run it.
#
#   multi-tenant (default): the commercial product. Many families under /f/<family>, a platform administrator
#                           creates them, a person can belong to several.
#   dedicated:              one family's own site (INSTANCE_MODE=dedicated, DEDICATED_FAMILY_SLUG=upton). The
#                           family lives at the site root, there is no /f/<family> in any address, no family
#                           picker and no platform pages.
module Instance
  def self.dedicated? = ENV["INSTANCE_MODE"] == "dedicated"
  def self.family_slug = ENV["DEDICATED_FAMILY_SLUG"].to_s

  # Shown in browser tabs when no family is open (sign-in, set-password).
  # The product's name in email copy.
  def self.product_name = ENV.fetch("PRODUCT_NAME", "Parallex Family")

  # Colour scheme: "parallex" is the Parallex LLC blue; anything else is the family reddish purple.
  # What a workspace is when none is open: the commercial instance sells to organizations, a dedicated one is a family.
  def self.default_kind = dedicated? ? "family" : "group"

  def self.brand = ENV["BRAND"].to_s

  # On a dedicated site the name shown before anyone signs in is the family's own name, not a generic word.
  def self.app_name
    return ENV["APP_NAME"] if ENV["APP_NAME"].present?
    (dedicated? && Family.find_by(slug: family_slug)&.name) || "Family"
  rescue ActiveRecord::ActiveRecordError
    "Family"
  end
end
