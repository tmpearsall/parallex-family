# One row per reminder item per member. The unique index is the guarantee that nobody is reminded of the same
# thing twice, even if the daily run happens twice.
class EmailDelivery < ApplicationRecord
  belongs_to :family
  belongs_to :membership
end
