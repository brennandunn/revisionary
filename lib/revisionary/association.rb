module Revisionary
  module Association
    module ClassMethods
      
      def register_owner(owner, polymorphic_assoc = nil)
        @revisionary_owner = owner
        @revisionary_polymorphic = polymorphic_assoc
      end
      
    end
    
    module InstanceMethods
      
      def set_owner(owner)
        assoc = self.class.reflect_on_all_associations.find { |a| a.klass == owner.class } rescue nil
        send(assoc ? "#{assoc.name}=" : "#{self.class.revisionary_polymorphic}=", owner)
      end
      
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.instance_eval do
        
        class << receiver
          
          attr_accessor :revisionary_owner
          attr_accessor :revisionary_polymorphic
          
        end
        
        before_update :clone
        
      end
    end
  end
end