class Page < ActiveRecord::Base
  establish_connection :page
  page = self.arel_table
  scope :under_version, ->(v) { where(page[:content_version].eq(nil).or(page[:content_version].lt(v))) }
  scope :not_redirect, -> { where page[:status].not_eq(STATUS::REDIRECT) }
  scope :has_content_version, -> { where page[:content_version].not_eq(nil) }
  scope :find_success_by_content_hash, ->(content_hash) { where(page[:content_hash].eq(content_hash).and(page[:status].eq(STATUS::SUCCESS)))}
  module STATUS
    NOT_PROCESSED = 10
    SUCCESS = Content::FETCH_ERROR::PROCESSED
    REDIRECT = 30
    ERROR_ON_OPEN = Content::FETCH_ERROR::ERROR_ON_OPEN
    ERROR_OTHER = Content::FETCH_ERROR::ERROR_OTHER
    HTTP_STATUS_NOT_200 = 110
    SAME_CONTENT_HASH = 120
  end

  include StatusFeature

  def grab_content(version = nil)
    content = Content.find_or_create_by(:id => self.id)
    content.update! :url => self.url
    r = content.grab
    if r[0]
      self.content_hash = Digest::SHA512.hexdigest(content.search_content)
      self.title = content.title
    end
    self.content_version = version if version and r[0]
    if (target = Page.find_success_by_content_hash(self.content_hash).first).present?
      self.target_page_id = target.id
      self.status = STATUS::SAME_CONTENT_HASH
    else
      self.status = r[1]
    end
    self.save!
    content.delete unless self.SUCCESS?
  end

  def self.grab_content(version)
    self.under_version(version).not_redirect.each { |p| p.grab_content version }
  end

  def self.clear_content_version
    self.update_all :content_version => nil
  end
end
