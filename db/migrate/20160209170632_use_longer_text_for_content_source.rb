class UseLongerTextForContentSource < ActiveRecord::Migration
  def change
    change_column :contents, :source, :text, :limit => 16777215
  end
end
