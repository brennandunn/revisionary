require 'test/unit'
require File.join(File.dirname(__FILE__), 'helper')

class RevisionaryTest < Test::Unit::TestCase

  def setup
    setup_db
  end
 
  def teardown
    teardown_db
  end
  
  def test_for_monitored_associations
    assert_equal(Page.associations, [:parts])
  end
  
  def test_for_hash_equality
    page = new_page
    page.commit! do |p|
      p.parts.create :name => 'Body'
    end
    
    assert_equal(page.commit_hash, page.object_hash)
  end
  
  def test_for_consitent_ids
    page = create_page
    page_id = page.id
    
    page.commit! { |p| p.name = 'One' }
    page.commit! { |p| p.name = 'Two' }
    page.commit! { |p| p.name = 'Three' }
    
    assert_equal(page_id, page.id)
  end

  def test_for_modifications_in_a_commit_block
    page = create_page
    page.commit! do |p|
      p.name = "Welcome to our website"
    end
        
    page.commit! do |p|
      p.name = "Google Inc"
    end    
    
    assert_equal(Page.find(:first).commits_count, 2)
    assert_equal(Page.find(:first).name, page.name)
  end
  
  def test_cloning_of_associations
    page = new_page
    page.commit! do |p|
      p.parts.create :name => 'Body'
      p.parts.create :name => 'Sidebar'
    end
    
    page.commit! do |p|
      p.parts.first.name = 'Body Area'
      p.name = 'Google Inc'
    end
    
    page.commit! do |p|
      p.parts.last.name = 'My area'
    end
    
    assert_equal(6, Part.count)
  end
  
  def test_ignoring_commiting_duplicates
    page = new_page
    page.commit!
    page.commit! # nothing has changed, this will be ignored
    page.commit! do |p|
      page.name = 'Testing name change'
    end
    
    assert_equal(1, page.commits_count)
  end
  
  def test_querying_for_previous_commits
    page = create_page :name => 'Previous Commit'
    page.commit! { |p| p.name = 'Current Commit' }
    
    assert_equal('Previous Commit', page.checkout(:previous).name)
    assert_equal(page.checkout(:previous), page.checkout(:root))
    assert_equal(page.checkout(:previous), page.checkout(1))
    assert_equal(page.checkout(:root), page.checkout(10)) # obviously there aren't 10 commits
  end
  
  def test_reverting_a_previous_commit
    page = create_page :name => 'Previous Commit'
    page.commit! { |p| p.name = 'Current Commit' }
    page.revert_to!(:previous)
    
    assert_equal(page.object_hash, page.checkout(:root).object_hash)
  end
  
  def test_reverting_a_previous_commit_with_associations
    page = new_page :name => 'Previous Commit'
    page.commit! do |p|
      p.parts.create :name => 'Body'
      p.parts.create :name => 'Sidebar'
    end
    
    page.commit! do |p|
      p.name = 'Current Commit'
      p.parts.first.name = 'New Body'
      p.parts.last.name = 'New Sidebar'
    end
    
    page.commit! do |p|
      p.name = 'Final Commit'
      p.parts.first.name = 'Final Body'
      p.parts.last.name = 'Final Sidebar'
    end
    
    page.revert_to!(:previous)
    
    assert_equal('Current Commit', page.name)
    
    page.revert_to!(:root)
    
    assert_equal('Previous Commit', page.name)
  end
  
  def test_ignored_attributes
    page = create_page :name => 'Home Page'
    
    page.set_live! # this is a method outside of Revisionary included in the Page class defined in helper.rb
    
    page.commit! do |p|
      p.name = 'My Home Page'
    end
    
    page.commit! do |p|
      p.name = 'Google Inc.'
    end
    
    page.update_attribute :live_hash, page.object_hash
    
    assert_nil page.checkout(:previous).live_hash
    assert page.live_hash
  end
  
  def test_query_for_live_page_by_live_hash
    # if you intend on having a live, approved version of a record in comparison to the head, this is useful
    page = create_page :name => 'Home Page'
    
    page.set_live!
    
    page.commit! { |p| p.name = 'Welcome Page' } # this is not approved
    
    assert_equal('Welcome Page', page.name)
    assert_equal('Home Page', page.checkout(page.live_hash).name)
    
  end
  
  # def test_commit_messages
  #   page = new_page
  #   page.commit! :message => 'Made some changes' do |p|
  #     p.name = 'Google Inc'
  #   end
  #   
  #   assert_equal('Made some changes', page.commit_message)
  # end
  # 
  # def test_tagging
  #   page = create_page
  #   page.commit! :tag => 'final' do |p|
  #     p.name = 'Final Commit'
  #   end
  #   
  #   page.commit! { |p| p.name = 'Maybe not' }
  #   
  #   assert_equal(Page.find(:all, :with_commits => true), [])
  #   assert_equal('Final Commit', page.checkout('tag:final').name)
  # end
  
  def new_page(options = {})
    Page.new({:name => "Home Page"}.merge(options))
  end
  
  def create_page(options = {})
    page = new_page(options)
    page.save
    page
  end

end
