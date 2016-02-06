class Lock < ActiveRecord::Base
  def self.loop
    lock = self.find_or_initialize_by :id => 1
    if lock.new_record?
      lock.save!
      yield
      sleep 10
      lock.delete
      begin
        client = HTTPClient.new
        client.receive_timeout = 0.0001
        client.get Settings.http_triggers.self
      rescue HTTPClient::ReceiveTimeoutError
# ignored
      end
    else
      yield
    end
  end
end
