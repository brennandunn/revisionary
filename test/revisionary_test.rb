require 'test/unit'
require File.join(File.dirname(__FILE__), 'helper')

class RevisionaryTest < Test::Unit::TestCase

  def setup
    setup_db
  end
 
  def teardown
    teardown_db
  end
  
  def test_instantiating_a_new_page
    page = Page.create
    part = page.parts.create
    assert_equal [], page.commit_hash
  end

end
