class Current < ActiveSupport::CurrentAttributes
  attribute :membership
  def family = membership&.family
  def user = membership&.user
end
