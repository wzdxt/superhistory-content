class Page < ActiveRecord::Base
  establish_connection :page
  page = self.arel_table
  scope :under_version, ->(v){where(page[:content_version].eq(nil).or(page[:content_version].lt(v)))}
  scope :not_redirect, -> {where page[:status].not_eq(STATUS::REDIRECT)}
  scope :has_content_version, -> {where page[:content_version].not_eq(nil)}
  module STATUS
    NOT_PROCESSED = 10
    PROCESSED = Content::FETCH_ERROR::PROCESSED
    REDIRECT = 30
    ERROR_ON_OPEN = Content::FETCH_ERROR::ERROR_ON_OPEN
    ERROR_OTHER = Content::FETCH_ERROR::ERROR_OTHER
  end

  def grab_content(version = nil)
    content = Content.find_or_create_by(:id => self.id)
    content.update! :url => self.url
    r = content.grab!
    self.content_version = version if version and r[0]
    self.status = r[1]
    self.save!
  end

  def self.grab_content(version)
    self.under_version(version).not_redirect.each{|p|p.grab_content version}
  end
end
