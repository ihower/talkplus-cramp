require "rubygems"
require "bundler"
require 'mysql2/em'
require "em-synchrony"
require "em-synchrony/connection_pool"

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

    def self.db
      @_db_config ||= eval(File.read('./config/database.rb'))
      @_db ||= EventMachine::Synchrony::ConnectionPool.new( :size => @_db_config[:pool_size] || 10 ) do
        Mysql2::EM::Client.new(:host => @_db_config[:host], 
                               :database => @_db_config[:database], 
                               :username => @_db_config[:username], 
                               :password => @_db_config[:password] )
      end
    end
    
    # Initialize the application
    def self.initialize!
      Cramp::Websocket.backend = :thin
    end

  end
end

Bundler.require(:default, CrampPubsub::Application.env)
require 'erb'
require 'stringio'
require 'yajl'

# Preload application classes
Dir['./app/**/*.rb'].each {|f| require f}