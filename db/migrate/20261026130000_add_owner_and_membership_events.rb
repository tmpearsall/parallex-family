# One owner per workspace: the only person who can add, promote or remove organizers. Every change to who organizes
# is recorded, so it is never silent.
class AddOwnerAndMembershipEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :memberships, :owner, :boolean, null: false, default: false
    add_index :memberships, :family_id, unique: true, where: "owner", name: "index_memberships_one_owner_per_family"
    # Existing workspaces: the longest-standing organizer is the owner until ownership is transferred.
    execute <<~SQL
      update memberships set owner = true
      where id in (select min(id) from memberships where role = 'organizer' group by family_id)
    SQL

    create_table :membership_events do |t|
      t.references :family, null: false, foreign_key: true
      t.references :actor_user, foreign_key: { to_table: :users }
      t.string :kind, null: false          # invited_organizer, made_organizer, made_member, removed_organizer, ownership_transferred
      t.string :target_label, null: false
      t.timestamps
    end
    add_index :membership_events, [ :family_id, :created_at ]
  end

  def down
    drop_table :membership_events
    remove_index :memberships, name: "index_memberships_one_owner_per_family"
    remove_column :memberships, :owner
  end
end
