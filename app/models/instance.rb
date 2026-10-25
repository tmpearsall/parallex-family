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
end
