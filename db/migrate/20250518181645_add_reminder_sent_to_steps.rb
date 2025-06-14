class AddReminderSentToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :reminder_sent, :boolean
  end
end
