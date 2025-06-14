class AddReminderSentToNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :notes, :reminder_sent, :boolean
  end
end
