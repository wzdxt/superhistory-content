class Page < ActiveRecord::Base
  establish_connection :page
  page = self.arel_table
  scope :under_version, ->(v) { where(page[:content_version].eq(nil).or(page[:content_version].lt(v))) }
  scope :not_redirect, -> { where page[:status].not_eq(STATUS::REDIRECT) }
  scope :not_same_content_hash, -> { where page[:status].not_eq(STATUS::SAME_CONTENT_HASH) }
  scope :has_content_version, -> { where page[:content_version].not_eq(nil) }
  scope :version, -> (v) { where(page[:content_version].eq(v)) }
  scope :content_hash, ->(content_hash) { where(page[:content_hash].eq(content_hash).and(page[:status].eq(STATUS::SUCCESS))) }
  scope :status_success, -> { where(page[:status].eq(STATUS::SUCCESS)) }
  scope :not_self, ->(self_id) { where(page[:id].not_eq(self_id)) }
  scope :id_desc, -> { order(:id => :desc) }
  module STATUS
    NOT_PROCESSED = 10
    SUCCESS = 20
    REDIRECT = 30
    ERROR_ON_OPEN = 40
    ERROR_OTHER = 50
    HTTP_STATUS_NOT_200 = 110
    SAME_CONTENT_HASH = 120
    RULE_EXCLUDED = 130
  end

  include StatusFeature

  def grab_content(version = nil, from_web = false)
    content, success, status = Content.grab(self, from_web)
    if success
      self.content_hash = content.search_content.present? ? Digest::SHA512.hexdigest(content.search_content) : nil
      self.title = content.title
      if version
        self.content_version = version
        if self.content_hash.present? and
            (target = Page.version(version).content_hash(self.content_hash).status_success.not_self(self.id).first).present?
          self.target_page_id = target.id
          self.status = STATUS::SAME_CONTENT_HASH
        else
          self.target_page_id = nil
          self.status = status
        end
      end
      self.save!
      self.status.nil? or self.SUCCESS? ? content.save! : content.delete
    else
      self.status = status
      self.save!
      content.delete
    end
  end

  def self.grab_content(version)
    # refetch randomly 10 pages in latest version
    count = self.version(version).count
    self.version(version).offset(rand(count - 9)).limit(1 + 9).each { |p| p.grab_content version, true }
    # version up for old version
    self.under_version(version).not_redirect.not_same_content_hash.id_desc.each { |p| p.grab_content version }
  end

  def self.clear_content_version
    self.update_all :content_version => nil, :status => STATUS::NOT_PROCESSED
  end
end
