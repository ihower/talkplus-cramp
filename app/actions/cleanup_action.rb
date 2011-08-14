class CleanupAction < Cramp::Action

  def start
    @redis = EM::Hiredis.connect("redis://localhost:6379")
    @channel = "talkplus-#{params[:id]}"
    
    @redis.del(@channel).callback do
      render "done"
      finish
    end
  end
end
