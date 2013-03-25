module MultiGit

  module Error

    class NotARepository < ArgumentError
      include Error
    end

    class RepositoryNotBare < NotARepository
      include Error
    end

    class RepositoryBare < NotARepository
      include Error
    end

    class InvalidObjectType < ArgumentError
      include Error
    end

    class InvalidReference < ArgumentError
      include Error
    end

    class AmbiguousReference < InvalidReference
    end

    class BadRevisionSyntax < InvalidReference
    end

    class NotYetImplemented < Exception
      include Error
    end

  end

end
