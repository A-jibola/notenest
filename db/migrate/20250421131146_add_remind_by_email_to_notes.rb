class AddRemindByEmailToNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :notes, :remind_by_email, :boolean
  end
end
