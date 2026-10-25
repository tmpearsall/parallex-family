class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.references :family, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :audience, null: false, default: "everyone"
      t.bigint :reunion_id
      t.string :subject
      t.text :body, null: false
      t.integer :recipient_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.timestamps
    end
    add_index :announcements, [ :family_id, :created_at ]
  end
end
