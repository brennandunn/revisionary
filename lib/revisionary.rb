$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'digest'
require 'activesupport' unless defined? ActiveSupport  
require 'activerecord' unless defined? ActiveRecord

require 'revisionary/base'
require 'revisionary/core'

ActiveRecord::Base.send(:include, Revisionary)