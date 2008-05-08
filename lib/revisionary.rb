$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'activesupport' unless defined? ActiveSupport  
require 'activerecord' unless defined? ActiveRecord

require 'revisionary/base'

ActiveRecord::Base.send(:include, Revisionary)