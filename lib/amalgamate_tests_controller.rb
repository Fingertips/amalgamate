require 'amalgamate'
#require File.join(RAILS_ROOT, 'test', 'js_tests_helper')

class AmalgamateTestsController < ApplicationController
  VIEW_PATH = File.expand_path('../../views/', __FILE__)
  
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
  
  prepend_around_filter do |controller, action|
    ActiveRecord::Base.transaction do
      action.call
      raise ActiveRecord::Rollback
    end
  end
end