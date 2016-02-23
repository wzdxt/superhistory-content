desc 'reset content'
task :reset  => :environment do
  p Content.reset_table
end