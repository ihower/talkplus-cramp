class ChatAction < Cramp::Websocket
  on_start :create_redis
  on_finish :handle_leave, :destroy_redis
  on_data :received_data
  
  def create_redis
    @pub = EM::Hiredis.connect("redis://localhost:6379")
    @sub = EM::Hiredis.connect("redis://localhost:6379")
  end
  
  def destroy_redis
    @pub.close_connection_after_writing
    @sub.close_connection_after_writing
  end
  
  def received_data(data)
    msg = parse_json(data)
    case msg[:action]
    when 'join'
      handle_join(msg)
    when 'message'
      handle_message(msg)
    else
      # skip
    end
  end
  
  def handle_join(msg)
    @user = msg[:user]
    @channel = msg[:channel]
    
    @channel_id = 1 # TODO: get channel_id by channel from mysql
    @user_id = 1 # TODO: get user_id by token from mysql
    
    subscribe
    publish :action => 'control', :user => @user, :message => 'joined the chat room'
          
    defer = CrampPubsub::Application.db.query "INSERT channel_users (channel_id, user_id, created_at) VALUES ('#{@channel_id}', '#{@user_id}', NOW())"
    
    # TODO
    #defer.callback do |result|
    #  puts "Result: #{result.inspect}"
    #  publish :action => 'assign', :uid => '1234567890' 
    #end
  end
  
  def handle_leave
    publish :action => 'control', :user => @user, :message => 'left the chat room'    
    CrampPubsub::Application.db.query "DELETE channel_users where channel_id = #{@channel_id} and user_id = #{@user_id}"
  end
  
  def handle_message(msg)
    publish msg.merge(:user => @user, :channel => @channel)
    content = msg[:message]
    CrampPubsub::Application.db.query "INSERT messages (channel_id, user_id, name, content, created_at) VALUES ('#{@channel_id}', '#{@user_id}', '#{@user}', '#{content}', NOW());"
  end
  
  private

  def subscribe
    @sub.subscribe(@channel)
    @sub.on(:message) {|channel, message| render(message) }    
  end
  
  def publish(message)
    @pub.publish(@channel, encode_json(message))
  end
  
  def encode_json(obj)
    Yajl::Encoder.encode(obj)
  end
  
  def parse_json(str)
    Yajl::Parser.parse(str, :symbolize_keys => true)
  end
end
