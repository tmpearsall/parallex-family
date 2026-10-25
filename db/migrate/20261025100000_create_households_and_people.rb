class CreateHouseholdsAndPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.string :name, null: false
      t.string :city
      t.string :region
      t.text   :notes
      t.timestamps
    end

    create_table :people do |t|
      t.references :household, foreign_key: true, null: true
      t.string  :first_name, null: false
      t.string  :last_name
      t.string  :maiden_name
      t.string  :nickname
      t.date    :birth_date
      t.date    :death_date
      t.string  :birth_place
      t.string  :occupation
      t.text    :notes
      t.string  :email
      t.boolean :hide_details, null: false, default: false   # minors: date of birth, notes and email shown only to admins and the person
      t.bigint  :created_by_id
      t.bigint  :updated_by_id
      t.timestamps
    end
    add_index :people, [ :last_name, :first_name ]

    create_table :relationships do |t|
      t.references :from_person, null: false, foreign_key: { to_table: :people }
      t.references :to_person,   null: false, foreign_key: { to_table: :people }
      t.string :kind, null: false          # "parent": from is a parent of to. "partner": from and to are partners (stored once).
      t.date   :started_on
      t.date   :ended_on
      t.string :notes
      t.timestamps
    end
    add_index :relationships, [ :from_person_id, :to_person_id, :kind ], unique: true, name: "index_relationships_uniqueness"
    add_check_constraint :relationships, "from_person_id <> to_person_id", name: "relationships_no_self"
    add_check_constraint :relationships, "kind in ('parent','partner')", name: "relationships_kind"
  end
end
