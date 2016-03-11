class Content < ActiveRecord::Base
  content = Content.arel_table
  scope :contains_localhost, -> { where content[:url].matches('%://localhost/%').or content[:url].matches('%://localhost:%') }

  UTF8 = 'utf-8'

  def grab(from_web = false)
    begin
      if from_web || self.source.blank?
        client = HTTPClient.new
        client.connect_timeout = client.send_timeout = client.receive_timeout = Settings.http_wait_time
        res = client.get self.url, :header => self.build_request_header
        return [false, Page::STATUS::HTTP_STATUS_NOT_200] unless res.status == 200
        readability_doc = Readability::Document.new(res.body)
        self.source = readability_doc.html.to_s.encode UTF8
        self.title = readability_doc.title
      end
      self.cache, self.title, included = self.get_preview
      self.search_content = self.clear_html_content
    rescue HTTPClient::ReceiveTimeoutError, HTTPClient::ConnectTimeoutError, HTTPClient::SendTimeoutError => e
      puts self.url
      puts e.class, e.message, e.backtrace
      return [false, Page::STATUS::ERROR_ON_OPEN]
    rescue => e
      puts self.url
      puts e.class, e.message, e.backtrace
      return [false, Page::STATUS::ERROR_OTHER]
    end
    return included ? [true, Page::STATUS::SUCCESS] : [false, Page::STATUS::RULE_EXCLUDED]
  end

  def grab!
    ret = self.grab
    self.save!
    ret
  end

  def self.grab(page, from_web = false)
    content = self.find_or_initialize_by(:id => page.id)
    content.url = page.url
    r = content.grab(from_web)
    [content] + r
  end

  def self.remove_existed_local
    self.contains_localhost.delete_all
  end

  def self.reset_table
    self.delete_all
  end

  # return cache, title
  def get_preview
    rule = self.get_rule
    if rule.nil?
      return Content.clear_cache(self.url, self.source), self.title, true
    elsif rule.excluded
      return nil, nil, false
    else
      doc = nokogiri_parse self.source
      title = doc.css(rule.title_css_path.downcase).text.strip
      h1 = Nokogiri::XML::Node.new 'h1', doc
      h1.add_child title
      ps = doc.css(rule.combined_content_css_path.downcase).map do |content_doc|
        p = Nokogiri::XML::Node.new 'p', content_doc
        p.add_child content_doc
        p
      end
      content = Nokogiri::HTML.parse(h1.to_s + ps.map { |p| p.to_s }.join).to_s
      return Content.clear_cache(self.url, content), title, true
    end
  end

  # return rule
  def get_rule
    uri = URI.parse self.url
    host, port, path = uri.host, uri.port, uri.path
    rule, include = HostRule.get_rule_by_host_port_path(host, port, path)
    if rule.nil?
      self.host_rule_id = self.path_rule_id = self.rule_excluded = nil
    else
      if rule.is_a? HostRule
        self.host_rule_id, self.path_rule_id = rule.id, nil
      elsif rule.is_a? PathRule
        self.host_rule_id, self.path_rule_id = rule.host_rule_id, rule.id
      end
      self.rule_excluded = !include
    end
    rule
  end

  def clear_html_content
    return nil if self.cache.nil?
    doc = Readability::Document.new(self.cache, :encoding => UTF8).html.css('body')
    doc.css('script, style, link').remove
    doc.text
        .gsub(/\s+/, ' ')
        .gsub(/[^\p{Word}|\p{P}|\p{S}|\s]+/, '') # 只保留中英文字,标点,符号和空格
        .gsub(/(?<=\P{Word})\s+(?=\p{Word})/, '') # 删除文字前空格
        .gsub(/(?<=\p{Word})\s+(?=\P{Word})/, '') # 删除文字后空格
        .strip
  end

  def build_request_header
    uri = URI.parse self.url
    root_addr = "#{uri.scheme}://#{uri.host}/"
    {'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
     'Accept-Language' => 'zh-CN,zh;q=0.8,en-US;q=0.6,en;q=0.4,ja;q=0.2,zh-TW;q=0.2',
     'Cache-Control' => 'no-cache',
     'Pragma' => 'no-cache',
     'Referer' => root_addr,
     'Upgrade-Insecure-Requests' => '1',
     'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.73 Safari/537.36'}
  end

  def self.clear_cache(url, content)
    uri = URI.parse url
    doc = Nokogiri::HTML.parse content
    doc.css('script, iframe, frameset, html>head, style, link').remove
    doc.css('img').each do |img|
      next if img['src'].start_with?('http://') or img['src'].start_with?('https://') or img['src'].start_with?('//')
      img['src'] = "#{uri.scheme}://#{uri.host}#{img['src']}"
    end
    doc.css('a').each do |a|
      next if a['href'].nil? or a['href'].start_with?('http://') or a['href'].start_with?('https://') or a['href'].start_with?('//')
      if a['href'].start_with?('javascript')
        a['href'] = nil
      else
        a['href']= "#{uri.scheme}://#{uri.host}#{a['href']}"
      end
    end
    doc.to_s
  end
end




