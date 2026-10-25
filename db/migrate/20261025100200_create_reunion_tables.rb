class CreateReunionTables < ActiveRecord::Migration[8.1]
  def change
    create_table :reunions do |t|
      t.string :title, null: false
      t.date   :starts_on
      t.date   :ends_on
      t.string :location_name
      t.string :address
      t.text   :description
      t.date   :rsvp_by
      t.bigint :created_by_id
      t.timestamps
    end

    create_table :date_options do |t|
      t.references :reunion, null: false, foreign_key: true
      t.date   :starts_on, null: false
      t.date   :ends_on
      t.string :note
      t.timestamps
    end

    create_table :date_votes do |t|
      t.references :date_option, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :answer, null: false   # yes, maybe, no
      t.timestamps
    end
    add_index :date_votes, [ :date_option_id, :user_id ], unique: true
    add_check_constraint :date_votes, "answer in ('yes','maybe','no')", name: "date_votes_answer"

    create_table :rsvps do |t|
      t.references :reunion, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.string  :status, null: false, default: "maybe"   # attending, maybe, not_attending
      t.integer :adults, null: false, default: 0
      t.integer :children, null: false, default: 0
      t.text    :dietary
      t.boolean :lodging_needed, null: false, default: false
      t.date    :arrival_on
      t.date    :departure_on
      t.text    :notes
      t.bigint  :updated_by_id
      t.timestamps
    end
    add_index :rsvps, [ :reunion_id, :household_id ], unique: true
    add_check_constraint :rsvps, "status in ('attending','maybe','not_attending')", name: "rsvps_status"

    create_table :tasks do |t|
      t.references :reunion, null: false, foreign_key: true
      t.string  :title, null: false
      t.text    :details
      t.references :claimed_by, foreign_key: { to_table: :users }, null: true
      t.boolean :done, null: false, default: false
      t.timestamps
    end

    create_table :board_posts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :board_posts }, null: true
      t.string  :title, limit: 120
      t.text    :body, null: false
      t.references :reunion, foreign_key: true, null: true
      t.boolean :pinned, null: false, default: false
      t.timestamps
    end
    add_index :board_posts, :created_at
    add_index :board_posts, [ :parent_id, :created_at ]
  end
end
