require 'multi_git/tree_entry'
require 'multi_git/repository'
require 'multi_git/rugged_backend/blob'
require 'multi_git/rugged_backend/tree'
require 'multi_git/rugged_backend/commit'
require 'multi_git/rugged_backend/ref'
require 'multi_git/rugged_backend/config'
require 'multi_git/rugged_backend/remote'
module MultiGit::RuggedBackend

  class Repository < MultiGit::Repository

    extend Forwardable
    extend MultiGit::Utils::Memoizes

  private
    OBJECT_CLASSES = {
      :blob => Blob,
      :tree => Tree,
      :commit => Commit
    }

  public

    # {include:MultiGit::Repository#bare?}
    delegate "bare?" => "@git"

    # {include:MultiGit::Repository#git_dir}
    def git_dir
      strip_slash @git.path
    end

    def git_work_tree
      strip_slash @git.workdir
    end

    def initialize(path, options = {})
      options = initialize_options(path,options)
      begin
        @git = Rugged::Repository.new(options[:repository])
        if options[:working_directory]
          @git.workdir = options[:working_directory]
        end
      rescue Rugged::RepositoryError, Rugged::OSError
        if options[:init]
          @git = Rugged::Repository.init_at(path, !!options[:bare])
        else
          raise MultiGit::Error::NotARepository, path
        end
      end
      @git.config = Rugged::Config.new(::File.join(@git.path, 'config'))
      verify_bareness(path, options)
    end

    # {include:MultiGit::Repository#write}
    # @param (see MultiGit::Repository#write)
    # @raise (see MultiGit::Repository#write)
    # @return (see MultiGit::Repository#write)
    def write(content, type = :blob)
      if content.kind_of? MultiGit::Builder
        return content >> self
      end
      validate_type(type)
      if content.kind_of? MultiGit::Object
        if include?(content.oid)
          return read(content.oid)
        end
        content = content.to_io
      end
      #if content.respond_to? :path
        # file duck-type
      #  oid = @git.hash_file(content.path, type)
      #  return OBJECT_CLASSES[type].new(@git, oid)
      #els
      if content.respond_to? :read
        # IO duck-type
        content = content.read
      end
      oid = @git.write(content.to_s, type)
      return OBJECT_CLASSES[type].new(self, oid)
    end

    # {include:MultiGit::Repository#read}
    # @param (see MultiGit::Repository#read)
    # @raise (see MultiGit::Repository#read)
    # @return (see MultiGit::Repository#read)
    def read(ref)
      oid = parse(ref)
      object = @git.lookup(oid)
      return OBJECT_CLASSES[object.type].new(self, oid, object)
    end

    # {include:MultiGit::Repository#ref}
    # @param (see MultiGit::Repository#ref)
    # @raise (see MultiGit::Repository#ref)
    # @return (see MultiGit::Repository#ref)
    def ref(name)
      validate_ref_name(name)
      Ref.new(self, name)
    end

    # {include:MultiGit::Repository#parse}
    # @param (see MultiGit::Repository#parse)
    # @raise (see MultiGit::Repository#parse)
    # @return (see MultiGit::Repository#parse)
    def parse(oidish)
      begin
        return Rugged::Object.rev_parse_oid(@git, oidish)
      rescue Rugged::ReferenceError => e
        raise MultiGit::Error::InvalidReference, e
      end
    end

    # {include:MultiGit::Repository#include?}
    # @param (see MultiGit::Repository#include?)
    # @raise (see MultiGit::Repository#include?)
    # @return (see MultiGit::Repository#include?)
    def include?(oid)
      @git.include?(oid)
    end

    def config
      Config.new(@git.config)
    end

    memoize :config

    TRUE_LAMBDA = proc{ true }

    def each_branch(filter = :all)
      return to_enum(:each_branch, filter) unless block_given?
      rugged_filter = nil
      if filter == :local || filter == :remote
        rugged_filter = filter
      end
      post_filter = TRUE_LAMBDA
      if filter.kind_of? Regexp
        post_filter = filter
      end
      Rugged::Branch.each(@git, rugged_filter) do |ref|
        next unless post_filter === ref.name
        yield Ref.new(self, ref)
      end
      return self
    end

    def each_tag
      return to_enum(:each_branch, filter) unless block_given?
      Rugged::Tag.each(@git) do |name|
        yield tag(name)
      end
      return self
    end

    # @api private
    # @visibility private
    def __backend__
      @git
    end

    # @api private
    # @visibility private
    def make_tree(entries)
      builder = Rugged::Tree::Builder.new
      entries.each do |name, mode, oid|
        builder << { name: name, oid: oid, filemode: mode}
      end
      oid = builder.write(@git)
      return read(oid)
    end

    # @api private
    # @visibility private
    def make_commit(options)
      rugged_options = {
        tree: options[:tree],
        message: options[:message],
        parents: options[:parents],
        author: {
          name:  options[:author].name,
          email: options[:author].email,
          time:  options[:time]
        },
        committer: {
          name:  options[:committer].name,
          email: options[:committer].email,
          time:  options[:commit_time]
        }
      }
      oid = Rugged::Commit.create(@git, rugged_options)
      return read(oid)
    end

    # 
    def remote( name_or_url )
      if looks_like_remote_url? name_or_url
        remote = Rugged::Remote.new(__backend__, name_or_url)
      else
        remote = Rugged::Remote.lookup(__backend__, name_or_url)
      end
      if remote
        if remote.name
          return Remote::Persistent.new(self, remote)
        else
          return Remote.new(self, remote)
        end
      else
        return nil
      end
    end

  private

    def strip_slash(path)
      return nil if path.nil?
      return path[0..-2]
    end

  end
end
