require "rubygems"
require "bundler"
require 'logger'

module CrampPubsub
  class Application

    def self.root(path = nil)
      @_root ||= File.expand_path(File.dirname(__FILE__))
      path ? File.join(@_root, path.to_s) : @_root
    end

    def self.env
      @_env ||= ENV['RACK_ENV'] || 'development'      
    end

    def self.routes
      @_routes ||= eval(File.read('./config/routes.rb'))
    end

    def self.logger
      @_logger ||= Logger.new( root + "/log/#{@_env}.log", 10, 100 * 1024 * 1024) # 100mb            
    end
    
    # Initialize the application
    def self.initialize!
      Cramp::Websocket.backend = :thin
      
      if env == "development"
        logger.level = Logger::DEBUG
      else
        logger.level = Logger::INFO
      end
    end

  end
end

Bundler.require(:default, CrampPubsub::Application.env)
require 'erb'
require 'stringio'
require 'yajl'

# Preload application classes
Dir['./app/**/*.rb'].each {|f| require f}