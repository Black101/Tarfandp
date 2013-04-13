require 'multi_git/repository'
require 'multi_git/tree_entry'
require 'multi_git/jgit_backend/blob'
require 'multi_git/jgit_backend/tree'
require 'multi_git/jgit_backend/commit'
module MultiGit::JGitBackend
  class Repository < MultiGit::Repository

    extend Forwardable

  private
    OBJECT_CLASSES = {
      :blob => Blob,
      :tree => Tree,
      :commit => Commit
    }

    # These IDs are magic numbers
    # from the Jgit code:
    OBJECT_TYPE_IDS = {
      :commit => 1,
      :tree => 2,
      :blob => 3,
      :tag => 4
    }

    REVERSE_OBJECT_TYPE_IDS = Hash[ OBJECT_TYPE_IDS.map{|k,v| [v,k]} ]
  public

    delegate "bare?" => "@git"

    def git_dir
      @git.getDirectory.to_s
    end

    def git_work_tree
      bare? ? nil : @git.getWorkTree.to_s
    end

    def initialize(path, options = {})
      options = initialize_options(path,options)
      builder = Java::OrgEclipseJgitStorageFile::FileRepositoryBuilder.new
      builder.setGitDir(Java::JavaIO::File.new(options[:repository]))
      if options[:working_directory]
        builder.setWorkTree(Java::JavaIO::File.new(options[:working_directory]))
      end
      if options[:index]
        builder.setIndexFile(Java::JavaIO::File.new(options[:index]))
      end
      @git = builder.build
      if !@git.getObjectDatabase().exists
        if options[:init]
          @git.create(!!options[:bare])
        else
          raise MultiGit::Error::NotARepository, path
        end
      end
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
      use_inserter do |inserter|
        begin
          t_id = OBJECT_TYPE_IDS[type]
          reader = nil
          if content.respond_to? :path
            path = content.path
            reader = Java::JavaIO::FileInputStream.new(path)
            oid = inserter.insert(t_id.to_java(:int), ::File.size(content.path).to_java(:long), reader)
          else
            content = content.read if content.respond_to? :read
            oid = inserter.insert(t_id, content.bytes.to_a.to_java(:byte))
          end
          return OBJECT_CLASSES[type].new(self, oid)
        ensure
          reader.close if reader
        end
      end
    end

    # {include:MultiGit::Repository#read}
    # @param (see MultiGit::Repository#read)
    # @raise (see MultiGit::Repository#read)
    # @return (see MultiGit::Repository#read)
    def read(read)
      java_oid = parse_java(read)
      object = use_reader{|rdr| rdr.open(java_oid) }
      type = REVERSE_OBJECT_TYPE_IDS.fetch(object.getType)
      return OBJECT_CLASSES[type].new(self, java_oid, object)
    end

    # @visibility private
    # @api private
    def make_tree(entries)
      fmt = Java::OrgEclipseJgitLib::TreeFormatter.new
      # git mktree and rugged tree builder sort entries by name
      # jgit tree builder doesn't
      entries.sort_by{|name, _, _| name }.each do |name, mode, oid|
        fmt.append(name,
                   Java::OrgEclipseJgitLib::FileMode.fromBits(mode),
                   Java::OrgEclipseJgitLib::ObjectId.fromString(oid))
      end
      use_inserter do |ins|
        oid = fmt.insertTo(ins)
        return read(oid)
      end
    end

    # {include:MultiGit::Repository#include?}
    # @param (see MultiGit::Repository#include?)
    # @raise (see MultiGit::Repository#include?)
    # @return (see MultiGit::Repository#include?)
    def include?(oid)
      @git.hasObject(Java::OrgEclipseJgitLib::ObjectId.fromString(oid))
    end

    # {include:MultiGit::Repository#parse}
    # @param (see MultiGit::Repository#parse)
    # @raise (see MultiGit::Repository#parse)
    # @return (see MultiGit::Repository#parse)
    def parse(ref)
      return Java::OrgEclipseJgitLib::ObjectId.toString(parse_java(ref))
    end

    # @visibility private
    # @api private
    def parse_java(oidish)
      return oidish if oidish.kind_of? Java::OrgEclipseJgitLib::AnyObjectId
      begin
        oid = @git.resolve(oidish)
        if oid.nil?
          raise MultiGit::Error::InvalidReference, oidish
        end
        return oid
      rescue Java::OrgEclipseJgitErrors::AmbiguousObjectException => e
        raise MultiGit::Error::AmbiguousReference, e
      rescue Java::OrgEclipseJgitErrors::RevisionSyntaxException => e
        raise MultiGit::Error::BadRevisionSyntax, e
      end
    end

    # @visibility private
    # @api private
    def use_reader
      begin
        rdr = @git.getObjectDatabase.newReader
        result = yield rdr
      ensure
        rdr.release if rdr
      end
    end

    # @visibility private
    # @api private
    def use_inserter
      begin
        rdr = @git.getObjectDatabase.newInserter
        result = yield rdr
      ensure
        rdr.release if rdr
      end
    end

    # @visibility private
    # @api private
    def __backend__
      @git
    end

  end
end
