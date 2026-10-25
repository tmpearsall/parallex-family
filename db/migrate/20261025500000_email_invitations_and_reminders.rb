class EmailInvitationsAndReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :email_reminders, :boolean, null: false, default: true
    add_column :memberships, :unsubscribe_token, :string
    add_index :memberships, :unsubscribe_token, unique: true

    add_column :invitations, :emailed_at, :datetime
    add_column :invitations, :email_error, :string

    create_table :email_deliveries do |t|
      t.references :family, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true
      t.string :kind, null: false          # e.g. "rsvp", "vote", "upcoming", "task", "event"
      t.string :item_key, null: false      # what exactly was reminded, so it is never sent twice
      t.string :status, null: false, default: "sending"   # sending, sent, failed
      t.string :error
      t.timestamps
    end
    add_index :email_deliveries, [ :membership_id, :kind, :item_key ], unique: true, name: "index_email_deliveries_once"
  end
end
