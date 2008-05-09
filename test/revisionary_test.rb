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
    
    assert_equal "15856dc487f63392ad9343a5a7e4e0f5fb32b295", page.commit_hash  # this an empty page with one page part
    
    page.parts.first.name = "Testing"
    
    assert_equal "8294b7d302d14b7501144eea388852d16e5fba98", page.commit_hash  # this an empty page with one page part set to 'testing'
  end
  
  def test_that_source_object_knows_itself
    page = Page.create
    
    assert_equal page.commit_hash, page.source_hash
  end
  
  def test_saving_a_page_and_skipping_equal_commit_hashes
    page = Page.create :name => "Home Page"
    part = page.parts.create :name => "Body Part"
    
    assert page.head?
    
    page.name = "New Home Page"
    
    part.name = "New Body Part"
        
    page.save   # ensure that saving a revisionary model also accounts for watched associations
    
    part.name = "Hello from Page Part"
    
    page.save
    page.save   # test that saving unmodified content does nothing   
    page.save
    
    page.name = "Hello from Page"
    
    page.save
    
    part.name = "Are we done yet?"
    
    page.save
     
    assert_equal Page.find(:first).root, Page.find(:first).ancestry.last
    assert_equal Page.find(:first).ancestry.size, 4
  end

end
