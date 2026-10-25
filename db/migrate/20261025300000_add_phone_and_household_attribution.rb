class AddPhoneAndHouseholdAttribution < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :phone, :string
    add_column :households, :created_by_id, :bigint
    add_column :households, :updated_by_id, :bigint
  end
end
