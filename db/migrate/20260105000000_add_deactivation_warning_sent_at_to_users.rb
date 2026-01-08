class AddDeactivationWarningSentAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :deactivation_warning_sent_at, :datetime, null: true
  end
end


