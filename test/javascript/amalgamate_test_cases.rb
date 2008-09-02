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