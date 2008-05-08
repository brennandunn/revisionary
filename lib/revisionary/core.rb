module Revisionary
  module Core
    
    module ClassMethods
      
      def apply_revisionary_to_associations
        self.associations.each do |assoc|
          self.reflect_on_association(:parts).klass.send(:include, Revisionary::Common)
        end
      end
      
      def clone_column?(col)
        %w(id source_hash object_hash is_head).include?(col)
      end
      
    end
    
    module InstanceMethods
      
      # access the source object
      def source_hash
        read_attribute(:source_hash) || self.commit_hash
      end
      
      def save_with_commit(*args)
        @commit_parameters ||= args.extract_options!
        @save_without_commit = true if @commit_parameters.delete :without_commit
        save_without_commit
      end

      def save_with_commit!(*args)
        @commit_parameters ||= args.extract_options!
        @save_without_commit = true if @commit_parameters.delete :without_commit
        save_without_commit!
      end
      
      def to_commit
        rev = self.clone
        rev.source_hash = self.object_hash
        
        self.class.column_names.each do |col|
          next if self.class.clone_column?(col)
          val = self.send("#{col}_changed?") ? self.send("#{col}_was") : self.send(col)
          self.send("#{col}=", val)
        end
        
        rev
      end
      
      private
        def setup_source_object
          self.object_hash = self.commit_hash
        end
    
        def prepare_to_commit
          return if self[:object_hash] == self.commit_hash
          @commit_object = self.to_commit
        end
        
        def commit
          if @commit_object
            @commit_object.save
          end
        end
      
    end
    
    def self.included(receiver)
      receiver.send :include, Revisionary::Common
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.instance_eval do
        
        alias_method_chain :save, :commit
        alias_method_chain :save!, :commit
        
        before_create :setup_source_object
        before_update :prepare_to_commit
        after_update :commit
        
      end
    end
    
  end
end