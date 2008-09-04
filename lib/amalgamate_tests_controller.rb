require 'amalgamate'

begin
  require 'application'
  # Try to require app/controllers/amalgamate_tests_controller.rb
  # which is the file where the user can open the controller class
  # and add code needed for the controller to work in her app.
  require 'amalgamate_tests_controller'
rescue LoadError
end

class AmalgamateTestsController < ApplicationController
  unloadable
  
  VIEW_PATH = File.expand_path('../../views/', __FILE__)
  
  prepend_around_filter :call_action_within_transaction
  Amalgamate.load_test_cases
  helper :all
  
  class << self
    attr_writer :controller_path
    def controller_path
      @controller_path ||= 'amalgamate_tests'
    end
  end
  
  def index
    render :file => File.join(VIEW_PATH, 'index.html.erb')
  end
  
  def runner
    if @test = Amalgamate.test_for_path_array(params_before_js_tests[:path])
      @test.setup_controller(self)
      render(@test.render_params)
    else
      flash[:error] = "Could not find an Amalgamate javascript test case for path \"/#{params_before_js_tests[:path].join('/')}\""
      redirect_to tests_url
    end
  end
  
  alias_method :params_before_js_tests, :params
  def params
    @test.nil? ? params_before_js_tests : @test.params
  end
  
  private
  
  def call_action_within_transaction
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  end
end