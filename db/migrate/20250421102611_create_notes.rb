class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.string :title
      t.text :description
      t.datetime :due_date
      t.datetime :reminder_time
      t.boolean :reminder_enabled
      t.references :user, null: false, foreign_key: true
      t.string :status

      t.timestamps
    end
  end
end
