# A person's mailing address and a second phone number. The mailing address is per person on purpose: a student
# on campus has a different one from the household they belong to.
class AddContactToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :phone2, :string
    add_column :people, :street1, :string
    add_column :people, :street2, :string
    add_column :people, :city, :string
    add_column :people, :state, :string
    add_column :people, :zip, :string
  end
end
