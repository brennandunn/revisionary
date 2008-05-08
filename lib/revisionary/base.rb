module Revisionary
  
  module ClassMethods
    
    def is_revisionary(options = {})
      self.send(:include, Revisionary::Core)
      class << self
        attr_accessor :revisionary_options
      end
      @revisionary_options = options
      apply_revisionary_to_associations
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
  end
end