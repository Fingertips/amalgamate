require 'action_controller/test_process'

module Amalgamate
  class JSTest
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
    include ActionView::Helpers::JavaScriptHelper
    
    attr_reader :test_case, :path, :template, :dependencies, :setup_proc
    
    def initialize(test_case_and_path, default_dependencies)
      @test_case, @path = test_case_and_path.to_a.first
      @test_case = "#{@test_case}_test"
      
      @dependencies = %w{ unittest }
      @dependencies.concat(default_dependencies) unless default_dependencies.blank?
    end
    
    # Takes a controller instance and sets it up for the test case.
    def setup_controller(controller_instance)
      controller_instance.class.controller_path = controller
      controller_instance.instance_eval(&setup_proc)
      controller_instance.instance_variable_get(:@template).content_for(:head) { content_for_head }
    end
    
    # Set the path to the template that should be rendered.
    # You only need to use this if the template path can't be inflected from the path.
    def template(template)
      @template = template
    end
    
    # Add a javascript dependency. A javscript include tag for this dependency will be
    # included in the output of <tt>content_for_head</tt> and thus automatically
    # added to the content_for(:head) queue.
    def depends_on(dep)
      @dependencies << dep
    end
    
    # Define the proc that's to be evaled in the controller to setup the environment.
    # Here you would normally do stuff like instantiate your fixture objects.
    #
    # Say you were testing a typical <tt>new</tt> page, you could then use the following
    # to instantiate a new model object:
    #
    #   setup do
    #     @member = Member.new
    #   end
    def setup(&block)
      @setup_proc = block
    end
    
    def path_array
      @path.split('/').reject { |x| x.empty? }
    end
    
    # The path to the test case file.
    # If the test case would be :googlemaps, the path would then be:
    # "RAILS_ROOT/test/javascript/googlemaps_test.js"
    def test_case_path
      File.join(RAILS_ROOT, 'test', 'javascript', "#{test_case}.js")
    end
    
    def test_log_div
      "Element.insert(document.getElementsByTagName('body')[0], { bottom: '<div id=\"testlog\"></div>' });"
    end
    
    def test_case_contents
      File.read(test_case_path)
    end
    
    def javascript
      javascript_tag "document.observe('dom:loaded', function() {\n  #{test_log_div}\n\n  #{test_case_contents}\n});"
    end
    
    # Returns the content that should be included in the head of the document.
    def content_for_head
      "#{include_tag}\n#{javascript}"
    end
    
    # Returns params that specify the template to render.
    def render_params
      { :template => (@template || "#{controller}/#{action}") }
    end
    
    def include_tag
      javascript_include_tag *@dependencies
    end
    
    def controller
      params[:controller]
    end
    
    def action
      params[:action]
    end
    
    # Returns the params as parsed by the routing engine.
    def params(request_method = nil)
      if @parameters
        @parameters
      else
        ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty?
        
        request = ActionController::TestRequest.new({}, {}, nil)
        request.env["REQUEST_METHOD"] = request_method.to_s.upcase if request_method
        request.path = @path
        
        ActionController::Routing::Routes.recognize(request)
        @parameters = request.path_parameters
      end
    end
  end
  
  class << self
    # Loads the file defining your test cases from: "test/javascript/amalgamate_test_cases.rb"
    def load_test_cases
      load File.join(RAILS_ROOT, 'test', 'javascript', 'amalgamate_test_cases.rb')
    end
    
    # Returns the array of defined JSTest instances.
    def tests
      @tests ||= []
    end
    
    # Define a JSTest instance where the key is the name of the test case and the value is the url path for this test.
    # It then takes a block which is evaled in the context of a </tt>JSTest</tt> instance, see </tt>JSTest</tt> for more info.
    #
    #   testing :googlemaps => '/members/1/edit' do
    #     depends_on 'googlemaps'
    #     
    #     setup do
    #       @member = Member.new
    #       @member.artist.build(:name => 'Pablo Picasso')
    #       @member.artist.build_avatar
    #       @member.save(false)
    #       
    #       @avatar = @member.artist.build_avatar
    #     end
    #   end
    def testing(test_case_and_path, &block)
      test = JSTest.new(test_case_and_path, @default_dependencies)
      test.instance_eval(&block)
      tests << test
    end
    
    # The array of default dependencies.
    attr_reader :default_dependencies
    
    # Add a default dependecy. All tests defined from that point on will receive this dependecy.
    # See <tt>JSTest#depends_on</tt> for more info.
    def depends_on(dep)
      (@default_dependencies ||= []) << dep
    end
    
    def test_for_path_array(path_array)
      tests.find { |t| t.path_array == path_array }
    end
  end
end