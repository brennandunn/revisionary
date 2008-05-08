module Revisionary
  module Core
    
    module ClassMethods
      
      def apply_revisionary_to_associations
        
      end
      
    end
    
    module InstanceMethods
      
      # the original object
      def source_hash
        read_attribute(:source_hash) || self.commit_hash
      end
      
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
    
  end
end