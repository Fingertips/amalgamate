RAILS_ROOT = File.expand_path('../../', __FILE__)

module Amalgamate
  module Initializer
    VENDOR_RAILS = File.expand_path('../../../../rails', __FILE__)
    OTHER_RAILS = File.expand_path('../../../rails', __FILE__)
    PLUGIN_ROOT = File.expand_path('../../', __FILE__)
    
    def self.rails_directory
      if File.basename(File.dirname(PLUGIN_ROOT)) == 'plugins'
        if File.exist?(VENDOR_RAILS)
          VENDOR_RAILS
        elsif File.exist?(OTHER_RAILS)
          OTHER_RAILS
        end
      end
    end
    
    def self.load_test_classes
      eval %{
        class ::Member < ::ActiveRecord::Base
          has_one :artist
        end
        class ::Artist < ::ActiveRecord::Base
          belongs_to :member
        end
        
        class ::ApplicationController < ::ActionController::Base; end
        class ::MembersController < ::ApplicationController; end
      }
      
      ActionController::Routing::Routes.draw do |map|
        map.resources :members
        map.tests '/tests', :controller => 'amalgamate_tests', :action => 'index'
        map.test  '/tests/*path', :controller => 'amalgamate_tests', :action => 'runner'
      end
      
      ActionController::Base.view_paths = File.join(RAILS_ROOT, 'test', 'views')
    end
    
    def self.load_dependencies
      if rails_directory
        $:.unshift(File.join(rails_directory, 'activesupport', 'lib'))
        $:.unshift(File.join(rails_directory, 'activerecord', 'lib'))
      else
        require 'rubygems' rescue LoadError
      end
      
      require 'activesupport'
      require 'activerecord'
      require 'actionpack'
      require 'action_controller'
      
      require 'rubygems' rescue LoadError
      
      require 'test/spec'
      require 'mocha'
    end
    
    def self.configure_database
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
      ActiveRecord::Migration.verbose = false
    end
    
    def self.setup_database
      ActiveRecord::Schema.define(:version => 1) do
        create_table :members do |t|
          t.timestamps
        end
        create_table :artists do |t|
          t.integer :member_id
          t.string  :name
        end
      end
    end
    
    def self.teardown_database
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    def self.load_plugin_files
      require 'amalgamate'
      require 'amalgamate_tests_controller'
    end
    
    def self.start
      load_dependencies
      load_test_classes
      load_plugin_files
      configure_database
    end
  end
end
Amalgamate::Initializer.start

module Amalgamate
  depends_on 'moksi'
  depends_on 'meti'
  
  testing :carousel => '/members/new' do
    setup do
      @member = Member.new
    end
  end
  
  testing :carousel => '/members/1' do
    template 'members/show'
    
    setup do
      @member = Member.create
      @member.create_artist(:name => 'Pablo Picasso')
    end
  end
  
  testing :googlemaps => '/members/1/edit' do
    depends_on 'googlemaps'
    
    setup do
      @member = Member.create
      @member.create_artist(:name => 'Pablo Picasso')
    end
  end
end

module AmalgamateSpecHelper
  def self.included(klass)
    klass.class_eval do
      after do
        Amalgamate::Initializer.teardown_database
        AmalgamateTestsController.controller_path = 'amalgamate_tests'
      end
    end
  end
  
  def path_to_param(path)
    path.split('/').reject { |x| x.empty? }
  end
end