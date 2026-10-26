# What the site sent and what the mail service later said happened to it (delivered, bounced, complained). Lets the site
# show organizers who is not being reached. Entries older than 90 days are purged by the daily run.
class CreateEmailLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :email_logs do |t|
      t.references :family, foreign_key: true
      t.string :kind, null: false                    # e.g. "invitation_mailer.invite"
      t.string :to_email, null: false
      t.string :subject
      t.string :status, null: false, default: "sending"   # sending, accepted, delivered, delayed, bounced, complained, failed
      t.string :detail
      t.datetime :status_at
      t.timestamps
    end
    add_index :email_logs, [ :to_email, :created_at ]
    add_index :email_logs, [ :family_id, :created_at ]
  end
end
