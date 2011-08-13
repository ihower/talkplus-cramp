class ListAction < Cramp::Action

  def start
    @redis = EM::Hiredis.connect("redis://localhost:6379")
    @channel = "talkplus-#{params[:id]}"
    
    @redis.smembers(@channel).callback do |value|
      puts value.inspect
      render value.to_s
      
      @redis.close_connection_after_writing     
      finish
    end
  end
end
