require 'test/unit'
require File.join(File.dirname(__FILE__), 'helper')

class RevisionaryTest < Test::Unit::TestCase

  def setup
    setup_db
  end
 
  def teardown
    teardown_db
  end
  
  def test_instantiating_a_new_page_with_association
    page = Page.create
    part = page.parts.create
    
    assert_equal "e8db9bd1e4a8ca364d45dfc49eb8e7b04bf2b431", page.commit_hash  # this an empty page with one page part
    
    page.parts.first.name = "Testing"
    
    assert_equal "339273857f8d3c37c28aea845faf08c2a8f19c0f", page.commit_hash  # this an empty page with one page part set to 'testing'
  end
  
  def test_that_source_object_knows_itself
    page = Page.create
    
    assert_equal page.commit_hash, page.source_hash
  end
  
  def test_saving_a_page
    page = Page.create :name => "Home Page"
    part = page.parts.create :name => "Body Part"
    
    page.update_attribute :name, "New Home Page"
    
    part.update_attribute :name, "New Body Part"
        
    assert_equal [], [Page.find(:all), Part.find(:all)]
  end

end
