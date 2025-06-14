class ChangeStatusToIntegerInNotes < ActiveRecord::Migration[8.0]
  def change
    change_column :notes, :status, :integer, using: 'status::integer', default: 0
  end
end
