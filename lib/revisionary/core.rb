module Revisionary
  module Core
    
    module ClassMethods
      
      def apply_revisionary_to_associations
        self.associations.each do |assoc|
          [Revisionary::Common, Revisionary::Association].each { |m| self.reflect_on_association(assoc).klass.send(:include, m) }
          self.reflect_on_association(assoc).klass.send(:register_owner, self, self.reflect_on_association(assoc).options[:as])
        end
      end
      
      def clone_column?(col)
        self.skipped_revisionary_attributes.include?(col)
      end
      
      def find_by_branch(*args)
        self.find_by_branch_id(args.first)
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
      
      def count_with_commits(*args)
        options = args.grep(Hash).first
        
        if options && options.delete(:with_commits)
          without_model_scope do
            count_without_commits(*args)
          end
        else
          count_without_commits(*args)
        end
      end
      
      def with_scope_with_commits(*args, &block)
        options = args.grep(Hash).first[:find]
        
        if options && options.delete(:with_commits)
          without_model_scope do
            with_scope_without_commits(*args, &block)
          end
        else
          with_scope_without_commits(*args, &block)
        end
      end
      
      
    end
    
    module InstanceMethods
      
      # access the source object
      def source_hash
        read_attribute(:source_hash) || self.commit_hash
      end
      
      # access the tag (if exists)
      def tag
        self.commit_tag
      end
      
      # check to see if current is tagged
      def tagged?
        not self.tag.nil?
      end
      
      # revert to another version, again, thanks to Rich of acts_as_revisable!
      def revert_to!(pointer, options = {}) 
        
        begin       
          revision =  case pointer
                      when :previous, :last, '^'
                        ancestry.first
                      when :root
                        ancestry.last
                      when '^^', '^2'
                        ancestry[1]
                      when /\^(\d+)/        # ^3, ^15, whatever.
                        ancestry[$1.to_i]
                      when Fixnum
                        ancestry[pointer-1]
                      when /tag:(.*)/
                        ancestry.find { |a| !a.commit_tag.blank? && a.commit_tag.downcase == $1.downcase }
                      when String
                        ancestry.find { |a| a.object_hash[pointer] }
                      end
        rescue
          revision = ancestry.last
        end
        
        if options[:soft]
          revision
        else
          self.reload_with(revision, :skip_protected => true)
          self.save
        end
      end
      alias :checkout! :revert_to!
      
      # this will just return the desired object, rather than forcefully reverting to it
      def checkout(pointer, options = {})
        self.revert_to!(pointer, options.merge({ :soft => true }))
      end
      alias :co :checkout
      alias :revert_to :checkout
      
      # an array of former commits ending at the base of the branch
      def ancestry(*args)
        params = args.extract_options!
        options = { :with_commits => true, :conditions => ["is_head = :head and (branch_id = :branch_id or id = :branch_id)", { :head => false, :branch_id => self.branch_id }], :order => 'object_created_at desc, id desc' }
        
        if params[:count]
          self.class.count(options)
        else
          options.merge!({ :limit => params[:depth]}) if params[:depth]
          self.class.find(:all, options)
        end
      end
      alias :ancestors :ancestry
      
      # helper for calling ancestry count
      def count_since_branch
        self.ancestry(:count => true)
      end
      
      # find the root of the current branch
      def root
        self.class.find(:first, :with_commits => true, :conditions => { :id => self.branch_id } )
      end
      
      # is this the head commit?
      def head?
        is_head?
      end
      
      protected
      
        def save_with_commit(*args)
          @commit_parameters ||= args.extract_options!
          trans_options = args.extract_options!
          @save_without_commit = true if @commit_parameters.delete :without_commit
          @branch = trans_options.delete(:branch)
          @staged_commit_message = trans_options.delete(:commit_message)    # do this better
          @staged_commit_tag = trans_options.delete(:tag)                   # *really* do this better...
          save_without_commit
        end

        def save_with_commit!(*args)
          @commit_parameters ||= args.extract_options!
          trans_options = args.extract_options!
          @save_without_commit = true if @commit_parameters.delete :without_commit
          @branch = trans_options.delete(:branch)
          @staged_commit_message = trans_options.delete(:commit_message)
          @staged_commit_tag = trans_options.delete(:tag)
          save_without_commit!
        end
      
        def setup_source_object
          self.object_hash = self.commit_hash
          self.is_head = true unless self.branch_id
          self.object_created_at = Time.now + 1.second
          self.save :without_commit => true
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
        
        def prepare_to_commit
          return if self[:object_hash] == self.commit_hash and !@branch
          self.is_head = false
          @commit_object = self.to_commit
        end
        
        def to_commit
          rev = self.clone
          rev.branch_id ||= @branch ? self.id : self.branch_id || self.id
          rev.source_hash = self.object_hash
          rev.is_head = true

          self.class.column_names.each do |col|
            next if self.class.clone_column?(col)
            val = self.send("#{col}_changed?") ? self.send("#{col}_was") : self.send(col)
            self.send("#{col}=", val)
          end

          rev
        end
        
        def commit
          if @commit_object and !@save_without_commit
            @commit_object.commit_message = @staged_commit_message
            @commit_object.commit_tag = @staged_commit_tag
            @commit_object.save
            self.clone_associations(@commit_object)
            self.reload_with(@commit_object)
            @commit_object = nil
            @save_without_commit = nil
            @branch = nil
            setup_source_object
          end
        end
        
        def reload_with(object, options = {})
          attributes = object.attributes
          attributes.reject! { |k, v| self.class.skipped_revisionary_attributes.include?(k) } if options[:skip_protected]
          @attributes.update(attributes)
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
        alias_method_chain :with_scope, :commits
        alias_method_chain :count, :commits
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