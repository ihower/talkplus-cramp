require 'digest/md5'
class ChatAction < Cramp::Websocket
  
  use_fiber_pool
  
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
    puts "Receive: #{data}\n"
    
    msg = parse_json(data)
    case msg[:action]
    when 'join'
      handle_join(msg)
    when 'message'
      handle_message(msg)
    else
      # skip
    end
    
    rescue
      puts "Parsing Error: #{data}"
  end
  
  def call_join
    join_callback = CrampPubsub::Application.db.query "SELECT name, id from users WHERE uid='#{@uid}'"    
    join_callback.callback do |result|
      @user_id = result.first["id"]
      @username ||= result.first["name"]

      subscribe
      publish :action => 'control', :user => @username, :message => 'joined the chat room'

      CrampPubsub::Application.db.query "INSERT channel_users (channel_id, user_id, created_at) VALUES ('#{@channel_id}', '#{@user_id}', NOW())"            
    end
  end
  
  def handle_join(msg)
    @username = msg[:user]
    @channel_id = msg[:channel]
    @channel = "talkplus-#{@channel_id}"
    @uid = msg[:uid]
    
    if @uid
      call_join           
    else
      @uid = Digest::MD5.hexdigest( rand(1000000).to_s + Time.now.to_s )
      defer = CrampPubsub::Application.db.query "INSERT users (name, uid, created_at) VALUES ('#{@username}','#{@uid}',NOW());"    
      defer.callback do |result|
        call_join     
      end
    end
    
  end
  
  
  def handle_leave
    publish :action => 'control', :user => @username, :message => 'left the chat room'    
    CrampPubsub::Application.db.query "DELETE channel_users where channel_id = #{@channel_id} and user_id = #{@user_id}"
  end
  
  def handle_message(msg)
    publish msg.merge(:user => @username, :channel => @channel)
    content = msg[:message]
    CrampPubsub::Application.db.query "INSERT messages (channel_id, user_id, name, content, created_at) VALUES ('#{@channel_id}', '#{@user_id}', '#{@username}', '#{content}', NOW());"
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
