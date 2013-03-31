require 'multi_git/tree'
require 'multi_git/jgit_backend/object'
module MultiGit::JGitBackend

  class Tree < Object

    EMPTY_BYTES = [].to_java :byte

    import 'org.eclipse.jgit.treewalk.CanonicalTreeParser'

    include MultiGit::Tree

    def raw_entries
      return @raw_entries if @raw_entries
      repository.use_reader do |reader|
        entries = []
        it = CanonicalTreeParser.new(EMPTY_BYTES, reader, java_oid)
        until it.eof
          mode = it.getEntryRawMode
          entries << [it.getEntryPathString, mode, ObjectId.toString(it.getEntryObjectId)]
          it.next
        end
        @raw_entries = entries
      end
      return @raw_entries
    end
  end
end
