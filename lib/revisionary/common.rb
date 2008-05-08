module Revisionary
  module Common

    module InstanceMethods
      
      # Generates unique hash for object and monitored associations
      def commit_hash
        hash = self.attributes.values.join(':')
        array = associations(true).inject([]) do |arr, (key, assoc)|
          arr << (assoc.is_a?(Array) ? assoc.map(&:commit_hash) : assoc.commit_hash)
        end
        Digest::SHA1.hexdigest([hash, array].flatten.join(':'))
      end
      
      # returns monitored associations
      def associations(load = false)
        assoc = [self.class.revisionary_options[:with] || []].flatten
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
      receiver.send :include, InstanceMethods
    end
  end
end