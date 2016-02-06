class CreateContents < ActiveRecord::Migration
  def change
    create_table :contents do |t|
      t.text :source
      t.string :url, :limit => 1000
      t.string :title
      t.text :cache
      t.text :search_content

      t.timestamps null: false
    end
  end
end
