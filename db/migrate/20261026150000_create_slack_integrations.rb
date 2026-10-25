# An organization's Slack channel: the incoming-webhook address (stored encrypted) and which kinds of message to post.
# Commercial site only. slack_posts is the guarantee a daily item is posted once.
class CreateSlackIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :slack_integrations do |t|
      t.references :family, null: false, foreign_key: true, index: { unique: true }
      t.text :webhook_ciphertext, null: false
      t.boolean :notify_meetings, null: false, default: true
      t.boolean :notify_forum, null: false, default: true
      t.boolean :notify_surveys, null: false, default: true
      t.boolean :notify_deadlines, null: false, default: true
      t.boolean :notify_messages, null: false, default: false
      t.string :last_status
      t.datetime :last_posted_at
      t.timestamps
    end

    create_table :slack_posts do |t|
      t.references :family, null: false, foreign_key: true
      t.string :item_key, null: false
      t.timestamps
    end
    add_index :slack_posts, [ :family_id, :item_key ], unique: true
  end
end
