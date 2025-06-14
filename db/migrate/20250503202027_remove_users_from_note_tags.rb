class RemoveUsersFromNoteTags < ActiveRecord::Migration[8.0]
  def change
    remove_reference :note_tags, :user, foreign_key: true

    add_reference :note_tags, :tag, null: false, foreign_key: true
    add_index :note_tags, [ :note_id, :tag_id ], unique: true
  end
end
