class ProcessController < ApplicationController
  layout false

  def index
    if params.keys.include? 'force'
      Lock.delete_all
    end
    Lock.loop do
      # Content.remove_existed_local
      Page.grab_content(9)
    end
    render :text => ''
  end
end
