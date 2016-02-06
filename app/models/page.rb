class Page < ActiveRecord::Base
  establish_connection :page
  page = self.arel_table
  scope :under_version, ->(v){where(page[:content_version].eq(nil).or(page[:content_version].lt(v)))}
  module STATUS
    NOT_PROCESSED = 10
  end

  def grab_content(version = nil)
    r = Content.find_or_create_by(:id => self.id).grab!(url)
    self.update! :content_version => version if version and r
  end

  def self.grab_content(version)
    self.under_version(version).each{|p|p.grab_content version}
  end
end
