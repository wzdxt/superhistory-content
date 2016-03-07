class PathRule < ActiveRecord::Base
  establish_connection :rule
  arel = self.arel_table
  belongs_to :host_rule
  scope :ord_order, -> { order(arel[:ord].eq(nil)).order(arel[:ord]) }

  def content_css_paths_data
    JSON.parse self.content_css_paths
  end

  def content_css_paths_data=(data)
    self.content_css_paths = data.to_json
  end

  def combined_content_css_path
    self.content_css_paths_data.join(',')
  end

  def combined_css_path
    ([self.title_css_path] + self.content_css_paths_data).join(',')
  end
end
