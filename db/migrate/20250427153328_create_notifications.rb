class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notifiable, polymorphic: true, null: false
      t.string :title
      t.text :body
      t.boolean :read
      t.datetime :send_at
      t.string :notification_type

      t.timestamps
    end
  end
end
