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

  def self.app_name = ENV.fetch("APP_NAME", "Family")
end
