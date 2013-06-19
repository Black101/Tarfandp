require 'multi_git/ref'
module MultiGit

  module RuggedBackend

    class Ref

      include MultiGit::Ref
      extend MultiGit::Utils::Memoizes

      # @api private
      def initialize(repository, name)
        if name.kind_of? Rugged::Reference
          ref = name
          name = ref.name
        else
          ref = Rugged::Reference.lookup(repository.__backend__, name)
        end
        super(repository, name)
        @rugged_ref = ref
      end

      def target
        return nil unless rugged_ref
        if rugged_ref.type == :symbolic
          repository.ref(rugged_ref.target)
        else
          repository.read(rugged_ref.target)
        end
      end

      memoize :target

    private
      attr :rugged_ref
    end

  end

end
