class Content < ActiveRecord::Base
  content = Content.arel_table
  scope :contains_localhost, -> {where content[:url].matches('%://localhost/%').or content[:url].matches('%://localhost:%')}

  module FETCH_ERROR
    PROCESSED = 20
    ERROR_ON_OPEN = 40
    ERROR_OTHER = 50
  end
  UTF8 = 'utf-8'

  def grab
    begin
      client = HTTPClient.new
      client.connect_timeout = client.send_timeout = client.receive_timeout = 3
      res = client.get self.url
      readability_doc = Readability::Document.new(res.body)
      self.source = readability_doc.html.to_s.encode UTF8
      self.title = readability_doc.title
      # self.cache = readability_doc.content.encode UTF8
      self.cache = self.source
      self.search_content = Readability::Document.new(self.cache).html.text
                                .gsub(/\s+/, ' ')
                                .gsub(/[^\p{Word}|\p{P}|\p{S}|\s]+/, '') # 只保留中英文字,标点,符号和空格
                                .gsub(/(?<=\P{Word})\s+(?=\p{Word})/, '') # 删除文字前空格
                                .gsub(/(?<=\p{Word})\s+(?=\P{Word})/, '') # 删除文字后空格
                                .strip
      self
    rescue HTTPClient::ReceiveTimeoutError, HTTPClient::ConnectTimeoutError, HTTPClient::SendTimeoutError => e
      puts self.url
      puts e.class, e.backtrace
      return [false, FETCH_ERROR::ERROR_ON_OPEN]
    rescue => e
      puts self.url
      puts e.class, e.backtrace
      return [false, FETCH_ERROR::ERROR_OTHER]
    end
    return [true, Page::STATUS::SUCCESS]
  end

  def grab!
    self.grab.save!
  end

  def self.remove_existed_local
    self.contains_localhost.delete_all
  end

  def self.reset_table
    self.delete_all
  end
end
