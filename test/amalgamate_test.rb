require File.expand_path('../test_helper', __FILE__)

describe "Amalgamate" do
  include AmalgamateSpecHelper
  
  before do
    @new_test, @show_test, @edit_test = Amalgamate.tests
  end
  
  it "should load a file defining the test cases for the application" do
    tests_before = Amalgamate.tests.dup
    deps_before = Amalgamate.default_dependencies.dup
    
    Amalgamate.load_test_cases
    Amalgamate.tests.length.should.be 6
    
    Amalgamate.instance_variable_set(:@tests, tests_before)
    Amalgamate.instance_variable_set(:@default_dependencies, deps_before)
  end
  
  it "should have recorded which paths we have configuration for" do
    Amalgamate.tests.length.should.be 3
    Amalgamate.tests.map(&:path).should == %w{ /members/new /members/1 /members/1/edit }
    Amalgamate.tests.map(&:test_case).should == %w{ carousel_test carousel_test googlemaps_test }
  end
  
  it "should instance eval the block on the JSTest instance" do
    instance = nil
    Amalgamate.testing(:foo => '/bar') { instance = self }
    
    instance.should.be.instance_of Amalgamate::JSTest
    instance.test_case.should == 'foo_test'
    instance.path.should == '/bar'
    
    Amalgamate.tests.pop
  end
  
  it "should return the correct test for a given path" do
    Amalgamate.test_for_path_array(path_to_param('/members/1/edit')).should.be @edit_test
    Amalgamate.test_for_path_array(path_to_param('/members/new')).should.be @new_test
    Amalgamate.test_for_path_array(path_to_param('/members/1')).should.be @show_test
  end
  
  it "should add default dependencies to each test case" do
    Amalgamate.default_dependencies.should == %w{ moksi meti }
    
    Amalgamate.tests.each do |test|
      test.dependencies.should.include 'moksi'
      test.dependencies.should.include 'meti'
    end
  end
end

describe "Amalgamate::JSTest" do
  include AmalgamateSpecHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::JavaScriptHelper
  
  before do
    Amalgamate::Initializer.setup_database
    @new_test, @show_test, @edit_test = Amalgamate.tests
  end
  
  it "should return the path it's testing as an array" do
    @new_test.path_array.should == ['members', 'new']
    @show_test.path_array.should == ['members', '1']
    @edit_test.path_array.should == ['members', '1', 'edit']
  end
  
  it "should return the path to the test case file" do
    @new_test.test_case_path.should == File.join(RAILS_ROOT, 'test', 'javascript', 'carousel_test.js')
    @edit_test.test_case_path.should == File.join(RAILS_ROOT, 'test', 'javascript', 'googlemaps_test.js')
  end
  
  it "should return the correct render params" do
    @new_test.render_params.should == { :template => 'members/new' }
    @show_test.render_params.should == { :template => 'members/show' }
    @edit_test.render_params.should == { :template => 'members/edit' }
  end
  
  it "should return the proper javascript to build a test run log div at the end of the body" do
    expected = "Element.insert(document.getElementsByTagName('body')[0], { bottom: '<div id=\"testlog\"></div>' });"
    @new_test.test_log_div.should == expected
  end
  
  it "should return the proper javascript include tags for inclusion in the page" do
    @new_test.include_tag.should == javascript_include_tag('unittest', 'moksi', 'meti')
    @edit_test.include_tag.should == javascript_include_tag('unittest', 'moksi', 'meti', 'googlemaps')
  end
  
  it "should return the contents of the test case file for inclusion in the page" do
    File.expects(:read).with(@edit_test.test_case_path).returns('$("foo").hide();')
    @edit_test.test_case_contents.should == '$("foo").hide();'
  end
  
  it "should return a javascript tag with code that makes the test runner run after the DOM has loaded" do
    @edit_test.stubs(:test_log_div).returns('<testlog>')
    @edit_test.stubs(:test_case_contents).returns('<contents>')
    
    expected = javascript_tag("document.observe('dom:loaded', function() {\n  <testlog>\n\n  <contents>\n});")
    @edit_test.javascript.should == expected
  end
  
  it "should return both the include tags and the test case file content" do
    @new_test.stubs(:include_tag).returns('<include>')
    @new_test.stubs(:javascript).returns('<javascript>')
    
    @new_test.content_for_head.should == "<include>\n<javascript>"
  end
  
  it "should take a setup block" do
    member = mock('Member')
    Member.expects(:new).returns(member)
    instance_eval(&@new_test.setup_proc)
    @member.should.be member
  end
  
  it "should return the params parsed from the path" do
    @new_test.params.should == HashWithIndifferentAccess.new(:controller => 'members', :action => 'new')
    @show_test.params.should == HashWithIndifferentAccess.new(:controller => 'members', :action => 'show', :id => '1')
  end
  
  it "should be able to get the controller and action from the route" do
    @new_test.controller.should == 'members'
    @new_test.action.should == 'new'
  end
  
  it "should take a controller instance and setup the environment for the test" do
    @new_test.stubs(:content_for_head).returns('<head content>')
    
    controller, template = create_controller_and_template
    @new_test.setup_controller(controller)
    
    AmalgamateTestsController.controller_path.should == 'members'
    controller.instance_variable_get(:@member).should.be.new_record
    template.result.should == { :head => '<head content>' }
  end
  
  private
  
  def create_controller_and_template
    template = Object.new
    def template.content_for(type, &block)
      @result = { type => block.call }
    end
    def template.result; @result; end
    
    controller = AmalgamateTestsController.new
    controller.instance_variable_set(:@template, template)
    
    [controller, template]
  end
end