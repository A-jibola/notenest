class CreateSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :steps do |t|
      t.string :name
      t.string :summary
      t.text :details
      t.datetime :due_date
      t.integer :order
      t.integer :status
      t.references :note, null: false, foreign_key: true

      t.timestamps
    end
  end
end
