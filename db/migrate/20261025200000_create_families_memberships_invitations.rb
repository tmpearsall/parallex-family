class CreateFamiliesMembershipsInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :families do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :families, :slug, unique: true

    create_table :memberships do |t|
      t.references :family, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"   # organizer, member
      t.references :person, foreign_key: true, null: true # this member's own place in that family's tree
      t.datetime :board_seen_at
      t.timestamps
    end
    add_index :memberships, [ :family_id, :user_id ], unique: true
    add_check_constraint :memberships, "role in ('organizer','member')", name: "memberships_role"

    create_table :invitations do |t|
      t.references :family, null: false, foreign_key: true
      t.string  :email, null: false
      t.string  :role, null: false, default: "member"
      t.references :person, foreign_key: true, null: true
      t.references :invited_by, foreign_key: { to_table: :users }, null: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :family_id, :email ]
    add_check_constraint :invitations, "role in ('organizer','member')", name: "invitations_role"
  end
end
