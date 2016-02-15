class UseUtf8mb4ForContents < ActiveRecord::Migration
  def change
    return unless Rails.env == 'production'
    table_name = 'contents'
    execute "alter table #{table_name} default character set utf8mb4 collate utf8mb4_unicode_ci"
    execute "alter table #{table_name} convert to character set utf8mb4 collate utf8mb4_unicode_ci"
  end
end
