module Revisionary
  
  module ClassMethods
    
    def is_revisionary(options = {})
      self.send(:include, Revisionary::Core, Revisionary::Common)
      class << self
        attr_accessor :revisionary_options
      end
      @revisionary_options = options
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
  end
end