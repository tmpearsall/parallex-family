class CreateEventsAndCalendarTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :family, null: false, foreign_key: true
      t.string :title, null: false
      t.date   :starts_on, null: false
      t.date   :ends_on
      t.string :time_note        # "2 pm", "after church": free text, so no time zones to get wrong
      t.string :location
      t.text   :notes
      t.references :reunion, foreign_key: true, null: true
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :events, [ :family_id, :starts_on ]

    add_column :memberships, :calendar_token, :string
    add_index :memberships, :calendar_token, unique: true
  end
end
