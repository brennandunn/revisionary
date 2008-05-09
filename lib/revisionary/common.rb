module Revisionary
  module Common
    
    module ClassMethods
      
      def associations
        [self.revisionary_options[:with] || []].flatten
      end
      
    end
    
    module InstanceMethods
      
      # Generates unique hash for object and monitored associations
      def commit_hash
        hash = self.attributes.reject { |k, v| [:id, :object_hash, :source_hash, :is_head, :object_created_at].include?(k.to_sym) }.values.join(':')
        array = associations(true).inject([]) do |arr, (key, assoc)|
          as = self.send(key)
          if as.is_a?(Array)
            as.map { |o| o.attributes.reject { |k, v| [:id, :page_id].include?(k.to_sym ) }.values.join(':') }.join(':')
          else
            # TODO
          end
        end
        Digest::SHA1.hexdigest([hash, array].flatten.join(':'))
      end
      
      # returns monitored associations
      def associations(load = false)
        return [] unless self.class.included_modules.include?(Revisionary::Core)
        self.class.apply_revisionary_to_associations
        assoc = self.class.associations
        if load
          assoc = assoc.inject({}) do |hsh, as|
            hsh[as] = send(as.to_sym)
            hsh
          end
        end
        assoc
      end
      
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end
end