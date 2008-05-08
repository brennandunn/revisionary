module Revisionary
  module Associated
    
    module InstanceMethods
      
    end
    
    def self.included(receiver)
      receiver.send :include, InstanceMethods
    end
  end
end