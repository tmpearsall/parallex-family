# Organizers' meetings, one-off or standing: an event only organizers can see, optionally repeating.
class AddMeetingsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :organizers_only, :boolean, null: false, default: false
    add_column :events, :repeat, :string, null: false, default: "none"     # none, weekly, biweekly, monthly
    add_column :events, :repeat_until, :date
    add_column :events, :skipped_dates, :jsonb, null: false, default: []
  end
end
