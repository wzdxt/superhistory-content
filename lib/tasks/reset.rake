desc 'reset content'
task :reset  => :environment do
  p Page.clear_content_version
  p Content.reset_table
end