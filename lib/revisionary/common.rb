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
        hash = self.attributes.reject { |k, v| [:object_hash, :source_hash, :is_head].include?(k.to_sym) }.values.join(':')
        array = associations(true).inject([]) do |arr, (key, assoc)|
          arr << (assoc.is_a?(Array) ? assoc.map(&:commit_hash) : assoc.commit_hash)
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