class Page < ActiveRecord::Base
  establish_connection :page
  page = self.arel_table
  scope :under_version, ->(v) { where(page[:content_version].eq(nil).or(page[:content_version].lt(v))) }
  scope :not_redirect, -> { where page[:status].not_eq(STATUS::REDIRECT) }
  scope :has_content_version, -> { where page[:content_version].not_eq(nil) }
  scope :version, -> (v) {where(page[:content_version].eq(v))}
  scope :content_hash, ->(content_hash) { where(page[:content_hash].eq(content_hash).and(page[:status].eq(STATUS::SUCCESS))) }
  scope :status_success, -> { where(page[:status].eq(STATUS::SUCCESS))}
  scope :not_self, ->(self_id) {where(page[:id].not_eq(self_id))}
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
    self.content_hash = Digest::SHA512.hexdigest(content.search_content) if r[0]
    self.title = content.title
    self.content_version = version if version and r[0]
    if version.present?
      if (target = Page.version(version).content_hash(self.content_hash).status_success.not_self(self.id).first).present?
        self.target_page_id = target.id
        self.status = STATUS::SAME_CONTENT_HASH
      else
        self.target_page_id = nil
        self.status = r[1]
      end
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
