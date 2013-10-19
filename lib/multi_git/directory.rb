require 'multi_git/tree'
require 'multi_git/tree_entry'
module MultiGit

  class Directory < TreeEntry

    module Base
      include Tree::Base
      def mode
        Utils::MODE_DIRECTORY
      end

      def size
        object.size
      end

      # @param [String] key
      # @return [TreeEntry, nil]
      def entry(key)
        e = object.entry(key)
        e.with_parent(self) if e
      end

      # @visibility private
      def walk_pre(&block)
        descend = block.call(self)
        return if descend == false
        each do |child|
          child.walk(:pre, &block)
        end
      end

      # @visibility private
      def walk_post(&block)
        each do |child|
          child.walk(:post, &block)
        end
        block.call(self)
      end

      # @visibility private
      def walk_leaves(&block)
        each do |child|
          child.walk(:leaves,&block)
        end
      end
    end

    class Builder < TreeEntry::Builder
      include Tree::Builder::DSL
      include Base

      # @return [Hash<String, TreeEntry::Builder>]
      def entries
        Hash[
          object.map{|entry| [entry.name, entry.with_parent(self) ] }
        ]
      end

      extend Forwardable

      delegate (Tree::Builder.instance_methods - self.instance_methods) => :object

      # @return [TreeEntry, nil]
      def from
        defined?(@from) ? @from : @from = make_from
      end

      # @visibility private
      # @api private
      def entry_set(key, value)
        object.entry_set(key, make_entry(key, value))
      end

    private

      def make_inner(*args)
        if args.any?
          if args[0].kind_of?(Tree::Builder)
            return args[0]
          elsif args[0].kind_of?(Directory)
            return args[0].object.to_builder
          elsif args[0].kind_of?(Tree)
            return args[0].to_builder
          end
        end
        Tree::Builder.new(*args)
      end

      def make_from
        if object.from.nil?
          nil
        else
          Directory::Builder.new(parent, name, object.from)
        end
      end
    end

    include Base

    # @return [Hash<String, TreeEntry>]
    def entries
      @entries ||= Hash[
        object.map{|entry| [entry.name, entry.with_parent(self) ] }
      ]
    end

  end

end
