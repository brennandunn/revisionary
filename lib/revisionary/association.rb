module Revisionary
  module Association
    module ClassMethods
      
      def register_owner(owner)
        @revisionary_owner = owner
      end
      
    end
    
    module InstanceMethods
      
      def set_owner(owner)
        assoc = self.class.reflect_on_all_associations.find { |a| a.klass == owner.class }
        send("#{assoc.name}=", owner)
      end
      
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.instance_eval do
        
        class << receiver
          
          attr_accessor :revisionary_owner
          
        end
        
        before_update :clone
        
      end
    end
  end
end