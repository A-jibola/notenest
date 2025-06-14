class DropAttachmentsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :attachments
  end
end
