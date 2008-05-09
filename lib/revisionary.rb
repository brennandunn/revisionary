$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'digest'
require 'activesupport' unless defined? ActiveSupport  
require 'activerecord' unless defined? ActiveRecord

require 'revisionary/scoped_model'
require 'revisionary/base'
require 'revisionary/common'
require 'revisionary/core'

ActiveRecord::Base.send(:include, Revisionary::ActsAsScopedModel)
ActiveRecord::Base.send(:include, Revisionary)