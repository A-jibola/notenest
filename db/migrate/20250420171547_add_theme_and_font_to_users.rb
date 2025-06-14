class AddThemeAndFontToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :theme, :string
    add_column :users, :font, :string
  end
end
