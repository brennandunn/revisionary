module Revisionary
  module Common
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
    
    module ClassMethods
      
      # columns to be skipped when creating comparison hashes
      def skipped_columns
        arr  = %w(source_hash object_hash original_commit_id commit_created_at commit_message commit_tag created_at updated_at) + [self.primary_key]
        arr += self.ignored_columns if self.included_modules.include?(Revisionary::Core)
        arr
      end
      
      def ignored_columns
        [self.revisionary_options[:ignore]].flatten.map(&:to_s)
      end
      
      # returns an array of monitored associations
      def associations
        return [] unless self.included_modules.include?(Revisionary::Core)
        [self.revisionary_options[:with]].flatten
      end
      
      def clone_column?(col)
        not self.skipped_columns.include?(col)
      end
      
    end
    
    module InstanceMethods
      
      def cloneable_attributes
        attributes.dup.reject { |k, v| !self.class.clone_column?(k.to_s) }
      end
      
      # generates a unique hash for object
      def commit_hash(origin_class = nil)
        @origin_class = origin_class
        combined  = self.attributes.reject { |k, v| self.class.skipped_columns.push(self.get_origin_foreign_key).flatten.include?(k.to_s) }.values.join(':')
        combined += self.class.associations.inject([]) do |arr, assoc_name|
                      association = self.send(assoc_name)
                      association.is_a?(Array) ? association.map { |a| a.commit_hash(self.class) } : association.commit_hash
                    end.join(':')
        #Digest::SHA1.hexdigest(combined)            
      end
      
      # revert columns in object to previous state - requires Rails 2.1
      def revert_columns(object)
        self.class.column_names.each do |col|
          next unless self.class.clone_column?(col)
          value = self.send("#{col}_changed?") ? self.send("#{col}_was") : self.send(col)
          object.send("#{col}=", value)
        end
      end
      
      protected
      # this will not work with polymorphic associations
        def get_origin_foreign_key
          if @origin_class
            return [@origin_class.revisionary_options[:polymorphic]].map { |p| [ "#{p}_type", "#{p}_id" ] }.flatten
            foreign_key = self.class.reflect_on_all_associations.find { |a| a.klass == @origin_class }.options[:foreign_key].to_s
            @foreign_key ||= foreign_key.blank? ? [@origin_class.name.downcase + '_id'] : [foreign_key]
          end
        end
      
    end
    
  end
end