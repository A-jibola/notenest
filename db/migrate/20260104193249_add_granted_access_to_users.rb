class AddGrantedAccessToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :granted_access, :boolean
  end
end
