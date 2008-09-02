require File.expand_path('../test_helper', __FILE__)
require 'amalgamate'

describe "An AmalgamateTestsController, in general", ActionController::TestCase do
  tests AmalgamateTestsController
  include AmalgamateSpecHelper
  
  it "should redirect to the index page when a test could not be found for the path given" do
    get :runner, :path => path_to_param('/turtles/1')
    assert_redirected_to tests_url
    flash[:error].should == 'Could not find an Amalgamate javascript test case for path "/turtles/1"'
  end
  
  it "should show all the available Amalgamate javascript test cases" do
    get :index
    
    assert_select "a[href=/tests/members/new]"
    assert_select "a[href=/tests/members/1]"
    assert_select "a[href=/tests/members/1/edit]"
  end
end

describe "A AmalgamateTestsController, when setting up", ActionController::TestCase do
  tests AmalgamateTestsController
  include AmalgamateSpecHelper
  
  before do
    Amalgamate::Initializer.setup_database
    @controller.stubs(:render)
    
    Amalgamate.tests.each { |test| test.stubs(:content_for_head).returns('') }
    @new_test, @show_test, @edit_test = Amalgamate.tests
  end
  
  it "should render with the correct params" do
    @controller.expects(:render).with(:template => 'members/show')
    get :runner, :path => path_to_param('/members/1')
  end
  
  it "should run the setup block" do
    Member.delete_all
    get :runner, :path => path_to_param('/members/1')
    Member.first.artist.name.should == 'Pablo Picasso'
  end
  
  it "should set the controller_path on the class to that of the controller from the params" do
    get :runner, :path => path_to_param('/members/1')
    AmalgamateTestsController.controller_path.should == 'members'
  end
  
  it "should change the params to match the controller and action being rendered" do
    get :runner, :path => path_to_param('/members/1')
    @controller.params.should == HashWithIndifferentAccess.new(:controller => 'members', :action => 'show', :id => '1')
  end
  
  it "should wrap the setup code in a transaction so we don't leave the database in a altered state" do
    @controller.stubs(:performed?).returns(true)
    assert_no_difference('Member.count') do
      get :runner, :path => path_to_param('/members/1')
    end
  end
end

describe "A AmalgamateTestsController, when rendering", ActionController::TestCase do
  tests AmalgamateTestsController
  include AmalgamateSpecHelper
  
  before do
    Amalgamate::Initializer.setup_database
    @new_test, @show_test, @edit_test = Amalgamate.tests
  end
  
  it "should be able to render a partial that is only specified by a name and not a path" do
    get :runner, :path => path_to_param('/members/1/edit')
  end
  
  it "should add the javascript include tags to the content_for(:head) queue" do
    get :runner, :path => path_to_param('/members/1/edit')
    content_for_head.should.include @edit_test.include_tag
  end
  
  it "should add the contents of the test case file to the content_for(:head) queue" do
    #File.expects(:read).with(@edit_test.test_case_path).returns(javascript)
    File.stubs(:read).with(File.join(RAILS_ROOT, 'test', 'views', 'members', 'edit.html.erb'))
    
    javascript = '$("foo").hide();'
    File.expects(:read).with(@edit_test.test_case_path).returns(javascript)
    
    get :runner, :path => path_to_param('/members/1/edit')
    content_for_head.should.include "<script type=\"text/javascript\">\n//<![CDATA[\n#{javascript}\n//]]>\n</script>"
  end
  
  private
  
  def content_for_head
    assigns(:template).instance_variable_get(:@content_for_head)
  end
end