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
    
    assert_equal "f62e0ea6edbc4288ff84c8da24f410ecf986229d", page.commit_hash  # this an empty page with one page part
    
    page.parts.first.name = "Testing"
    
    assert_equal "e122f9073ed0e1ebfb7ca779a8977944374b21c4", page.commit_hash  # this an empty page with one page part set to 'testing'
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
    assert_equal Page.find(:first).ancestry(:count => true), Page.find(:first).ancestry.size
  end
  
  def test_commit_messages
    page = Page.create :name => "Company Profile", :commit_message => "Initializing"
    
    page.name = "New Company Profile"
    page.save :commit_message => "Changed name of page"
    
    assert_equal "Changed name of page", Page.find(:first).commit_message
  end
  
  def test_tagging_of_commits
    page = Page.create :name => "Company Profile"
    
    page.name = "New Company Profile"
    page.save :tag => 'default_commit'
    
    assert_equal 'default_commit', page.tag
  end
  
  def test_checking_out_old_pages
    
    page = Page.create :name => "About Us"
    
    page.name = "Beginner About Us"
    page.save :tag => "beginner"
    
    page.update_attribute :name, "A Newer About Us"
    page.update_attribute :name, "An Even Better About Us"
    
    assert_equal "About Us", page.co(3).name
    assert_equal "A Newer About Us", page.checkout(:previous).name
    assert_equal "Beginner About Us", page.checkout("beginner").name
        
  end
  
  def test_reverting
    
    page = Page.create :name => "About Us"
    part = page.parts.create :name => "Test"
    
    page.name = "New About Us"
    part.name = "New Test"
    page.save
    
    page.revert_to!(:root)
    
    assert_equal Page.find(:first).checkout(:root).name, Page.find(:first).name        
  end

end
