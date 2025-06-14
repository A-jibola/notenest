class AddReminnderFieldsToSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :steps, :remind_at, :datetime
    add_column :steps, :reminder_enabled, :boolean
    add_column :steps, :remind_by_email, :boolean
  end
end
