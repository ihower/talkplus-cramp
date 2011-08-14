require 'eventmachine'
require 'em-http-request'
 
CHANNEL=2
CONNECTION_SIZE = 100

EventMachine.run {  
  http=[]  
  1.upto(CONNECTION_SIZE) do |i|
    http[i] = EventMachine::HttpRequest.new("ws://localhost:3000/websocket").get :timeout => 0
    
    http[i].errback { puts "oops" }
    http[i].callback {
      puts "WebSocket connected!"
      http[i].send("{ \"action\":\"join\", \"user\":\"bot_#{i}\", \"channel\": #{CHANNEL} }")      
    }
    
    http[i].stream { |msg|
      puts msg
    }
  end
}
