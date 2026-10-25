class AddKindToFamilies < ActiveRecord::Migration[8.1]
  def change
    add_column :families, :kind, :string, null: false, default: "family"   # "family" or "group"
    add_check_constraint :families, "kind in ('family','group')", name: "families_kind"
  end
end
