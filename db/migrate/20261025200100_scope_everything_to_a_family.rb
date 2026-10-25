# Every family-owned table gets a family_id. Existing rows (the single-family prototype) are moved into one
# first family, and each existing account becomes a member of it (admins become organizers).
class ScopeEverythingToAFamily < ActiveRecord::Migration[8.1]
  TABLES = %i[households people relationships reunions board_posts].freeze

  def up
    TABLES.each { |t| add_reference t, :family, foreign_key: true, null: true, index: true }
    add_column :users, :platform_admin, :boolean, null: false, default: false

    needs_family = execute("select (select count(*) from users) + (select count(*) from people) + (select count(*) from households) + (select count(*) from reunions) as n").first["n"].to_i > 0
    if needs_family
      fid = execute("insert into families (name, slug, created_at, updated_at) values ('Family', 'family', now(), now()) returning id").first["id"]
      TABLES.each { |t| execute("update #{t} set family_id = #{fid.to_i}") }
      execute(<<~SQL)
        insert into memberships (family_id, user_id, role, person_id, board_seen_at, created_at, updated_at)
        select #{fid.to_i}, id, case when admin then 'organizer' else 'member' end, person_id, board_seen_at, now(), now() from users
      SQL
      execute("update users set platform_admin = true where admin")
    end

    TABLES.each { |t| change_column_null t, :family_id, false }
    remove_reference :users, :person, foreign_key: true, index: true
    remove_column :users, :admin
    remove_column :users, :board_seen_at
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
