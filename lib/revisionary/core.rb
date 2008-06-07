module Revisionary
  module Core
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      
      class << receiver
        alias_method_chain :find, :commits
        alias_method_chain :count, :commits
      end
      
      receiver.instance_eval do
        
        alias_method_chain :save, :commit
        alias_method_chain :save!, :commit
        
        # this will ensure that we only ever find the actual object, not the commits
        acts_as_scoped_model :find => { :conditions => { :original_commit_id => nil } }
                
        before_save :setup_commit
        before_update :clone_previous
        after_update :save_commit
        
        attr_accessor :revisionary_commit_tag
        
      end
      
    end
    
    module ClassMethods
      
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
      
    end
    
    module InstanceMethods
      
      def commits(conditions = {})
        scope, count = conditions.delete(:scope), conditions.delete(:count)
        options = { :conditions => { :original_commit_id => self.id }.merge(conditions), :order => 'commit_created_at desc, id desc', :with_commits => true }
        count ? self.class.count(options) : self.class.find(scope || :all, options)
      end
      
      def commits_count
        commits(:count => true)
      end
      
      def revert_to!(pointer, options = {})
        begin
          revision =  case pointer
                      when :previous
                        commits(:scope => :first)
                      when :root
                        commits(:scope => :last)
                      when Fixnum
                        commits[pointer-1] || commits(:scope => :last)
                      when /tag:(.*)/
                        commits(:scope => :first, :commit_tag => $1)
                      when String
                        commits(:scope => :first, :object_hash => pointer)
                      end
        rescue
           revision = commits(:scope => :last)
        end
        
        revision ||= commits(:scope => :first)
        
        if options[:soft]
          revision
        else
          @transitory_revision = revision
          self.commit! do |s| 
            s.attributes = revision.cloneable_attributes
          end
          @transitory_revision = nil
          self
        end
      end
      
      def checkout(pointer, options = {})
        self.revert_to!(pointer, options.merge({ :soft => true }))
      end
      
      def commit(options = {}, &block)
        return unless block_given?
        
        begin
          commit_mutex(:start)
          if self.new_record?
            @stepping_out_of_commit = true
            self.save
          end
          yield(self)
          self.commit_message = options[:message]
        ensure
          commit_mutex(:stop)
        end
        
      end
      
      def commit!(options = {}, &block)
        returning(commit(options, &block)) do
          save!
        end
      end
      
      def in_commit?
        !@commit_mutex.nil?
      end
      
      protected
        def save_with_commit(*args)
          @commit_params ||= args.extract_options!
          @save_without_commit = @commit_params.delete(:without_commit)
          save_without_commit(*args)
        end
        
        def save_with_commit!(*args)
          @commit_params ||= args.extract_options!
          @save_without_commit = @commit_params.delete(:without_commit)
          save_without_commit!(*args)
        end
        
        def setup_commit
          unless @commit_mutex
            self.object_hash = self.commit_hash
            self.commit_created_at = Time.now + 1.second
          end
          self.commit_tag ||= @commit_tag
        end
        
        def clone_previous
          unless @commit_mutex or @stepping_out_of_commit
            @commit_object = self.to_commit
            @commit_object = nil if self.commit_hash == @commit_object.commit_hash
          end
          @stepping_out_of_commit = false
          self
        end
        
        def clone_associations(object)
          # there must be a better way to do all of this
          self.class.associations.each do |assoc|
              clones =  (@transitory_revision || self).send("#{assoc}").map { |a| n = a.clone; a.revert_columns(n); n }
              self.send("#{assoc}").map(&:save)
              object.send("#{assoc}=", clones)
              if @transitory_revision # need to do this so as to not use the previous commit as a source, but the commit reverting to
                assoc_id = "#{assoc.to_s.singularize}_ids"
                original_ids, new_ids = self.send(assoc_id), object.send(assoc_id)
                self.send("#{assoc_id}=", new_ids)
                object.send("#{assoc_id}=", original_ids)
              end
          end
        end
        
        def save_commit
          if @commit_object
            @commit_object.save
            self.clone_associations(@commit_object)
            @commit_object = nil
          end
        end
        
        def to_commit
          returning(self.clone) do |obj|
            self.revert_columns(obj)
            self.source_hash = obj.commit_hash
            obj.original_commit_id = self.id
            self.class.ignored_columns.each { |i| obj.send("#{i}=", nil)}
          end
        end
        
        def commit_mutex(flag)
          @commit_mutex = flag == :start ? true : false
        end
      
    end
    
  end
end