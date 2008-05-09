module Revisionary
  module Core
    
    module ClassMethods
      
      def apply_revisionary_to_associations
        self.associations.each do |assoc|
          [Revisionary::Common, Revisionary::Association].each { |m| self.reflect_on_association(assoc).klass.send(:include, m) }
          self.reflect_on_association(assoc).klass.send(:register_owner, self)
        end
      end
      
      def clone_column?(col)
        %w(id source_hash object_hash object_created_at is_head).include?(col)
      end
      
      def find_with_commits(*args)
        options = args.grep(Hash).first
        
        if options && options.delete(:with_commits)
          without_model_scope do
            find_without_commits(*args)
          end
        else
          find_without_commits(*args)
        end
        
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
        rev.branch_id = self.branch_id || self.id
        rev.source_hash = self.object_hash
        rev.object_created_at = Time.now + 1.second
        rev.is_head = true
        
        self.class.column_names.each do |col|
          next if self.class.clone_column?(col)
          val = self.send("#{col}_changed?") ? self.send("#{col}_was") : self.send(col)
          self.send("#{col}=", val)
        end
        
        rev
      end
      
      def clone_associations(receiver)
        self.associations(true).each do |key, object|
          if object.is_a?(Array)
            object.map { |o| n = o.clone; n.set_owner(receiver); n.save; n }
          else
            n = object.clone
            n.set_owner(receiver)
            n.save
            n
          end
        end
      end
      
      def ancestry(depth = nil)
        options = { :with_commits => true, :conditions => ["is_head = ? and (branch_id = ? or id = ?)", false, self.branch_id, self.branch_id], :order => 'object_created_at desc, id desc' }
        options.merge!({ :limit => depth}) if depth
        self.class.find(:all, options)
      end
      
      def root
        self.class.find(:first, :with_commits => true, :conditions => { :id => self.branch_id } )
      end
      
      def head?
        is_head?
      end
      
      protected
        def setup_source_object
          self.object_hash = self.commit_hash
          self.is_head = true unless self.branch_id
          self.save :without_commit => true
        end
    
        def prepare_to_commit
          return if self[:object_hash] == self.commit_hash
          self.is_head = false
          @commit_object = self.to_commit
        end
        
        def commit
          if @commit_object and !@save_without_commit
            @commit_object.save
            self.clone_associations(@commit_object)
            self.reload_with(@commit_object)
            @commit_object = nil
            @save_without_commit = nil
            setup_source_object
          end
        end
        
        def reload_with(object)
          @attributes.update(object.attributes)
          @attributes_cache = {}
          self
        end
      
    end
    
    def self.included(receiver)
      receiver.send :include, Revisionary::Common
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      
      class << receiver
        alias_method_chain :find, :commits
      end
      
      receiver.instance_eval do
        
        alias_method_chain :save, :commit
        alias_method_chain :save!, :commit
        
        acts_as_scoped_model :find => { :conditions => { :is_head => true } } 
                
        after_create :setup_source_object
        before_update :prepare_to_commit
        after_update :commit
        
      end
    end
    
  end
end