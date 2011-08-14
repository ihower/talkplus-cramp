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
    rescue => e
      CrampPubsub::Application.logger.error "Error in destroy_redis: #{e}"
  end
  
  def received_data(data)
    data.chop!
    return if data == ""
    
    begin
      CrampPubsub::Application.logger.debug "Receive: #{data}\n"
      
      msg = parse_json(data)
      case msg[:action]
      when 'join'
        handle_join(msg)
      when 'message'
        handle_message(msg)
      when 'leave'
        handle_leave    
      else
        # skip
      end    
    rescue => e
      CrampPubsub::Application.logger.error "Error in received_data: |#{data}| #{e}"
    end
  end
  
  def call_join   
    subscribe
    @pub.sadd @channel, @username
    
    @pub.scard(@channel).callback do |value|
      publish :action => 'control', :user => @username, 
              :message => "joined the chat room. We have #{value} people now!",
              :users_count => value
      CrampPubsub::Application.logger.info "#{@username} join #{@channel}, #{value} people"
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
      call_join     
    end    
  end
  
  def handle_leave
    begin      
      @pub.srem @channel, @username
      
      @pub.scard(@channel).callback do |value|
        publish :action => 'control', :user => @username, :message => "left the chat room. We have #{value} people.", :users_count => value
        CrampPubsub::Application.logger.info "#{@username} leave #{@channel}, #{value} people"
        finish        
      end      
    rescue => e
      CrampPubsub::Application.logger.error "Error in handle_leave: #{e}"
      finish
    end
  end
  
  def handle_message(msg)
    publish msg.merge(:user => @username, :channel => @channel)
    content = msg[:message]
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
