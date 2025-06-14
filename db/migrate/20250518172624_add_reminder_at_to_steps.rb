class AddReminderAtToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :reminder_at, :datetime
  end
end
