require 'git'
module MultiGit
  module GitBackend
    class << self

      def load!
      end

      def open(path, options = {})
        Repository.new(path, options)
      end

    end
  end
end
require 'multi_git/git_backend/repository'
