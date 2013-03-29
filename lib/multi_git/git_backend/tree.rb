require 'multi_git/tree'
require 'multi_git/git_backend/object'
module MultiGit::GitBackend
  class Tree

    LS_TREE_REGEX = /^([0-7]{6}) (blob|tree|commit) (\h{40})\t(.+)$/

    include MultiGit::Tree
    include MultiGit::GitBackend::Object

    def raw_entries
      @raw_entries ||= begin
        @git.io('ls-tree', oid) do |io|
          io.each_line.map do |line|
            raise unless LS_TREE_REGEX =~ line
            [$4,$1.to_i(8),$3,$2.to_sym]
          end
        end
      end
    end

  end
end
