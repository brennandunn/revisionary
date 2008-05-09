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
  is_revisionary :with => :parts
end

class Part < ActiveRecord::Base
  belongs_to :page
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
 
def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    
    create_table :pages do |t|
      t.string        :name
      
      t.string        :object_hash
      t.datetime      :object_created_at
      t.string        :source_hash
      t.integer       :branch_id
      t.boolean       :is_head
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