begin
  require File.dirname(__FILE__) + '/../../../../config/environment'
rescue LoadError
  require 'rubygems'
  require 'activerecord'
  require 'activesupport'
end

require File.join(File.dirname(__FILE__), '..', 'lib', 'revisionary')

class Page < ActiveRecord::Base
  has_many :parts
  is_revisionary :with => :parts, :ignore => :live_hash
  
  def set_live!
    update_attribute :live_hash, self.object_hash
  end
  
end

class Part < ActiveRecord::Base
  belongs_to :page
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
 
def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    
    create_table :pages do |t|
      t.string        :name
      t.string        :live_hash  # a way of having a 'live' commit as opposed to the standard head
      
      t.string        :object_hash
      t.datetime      :commit_created_at
      t.string        :source_hash
      t.integer       :original_commit_id
      t.string        :commit_message
      t.string        :commit_tag
    end
    
    create_table :parts do |t|
      t.belongs_to    :page
      t.string        :name
      t.text          :content
    end

  end
end
 
def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end