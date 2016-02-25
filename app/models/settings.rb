class Settings < Settingslogic
	source "#{Rails.root}/config/application.yml"
	namespace Rails.env

  Dir[Rails.root.join('config/settings/*')].each do |file_path|
    instance.deep_merge!(Settings.new(file_path))
  end

end