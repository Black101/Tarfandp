module MultiGit
  # Encapsulates name + email. Mostly used for commits.
  class Handle < Struct.new(:name, :email)

  private
    EMAIL = /\A\w+@\w+\.\w+\z/ # close enough, but
    NAME_WITH_EMAIL = /\A(.*) <(\S+@\S+\.\S+)>\z/
  public

    # Parses a handle from a string
    #
    # @param [String]
    # @return [Handle]
    #
    # @example
    #   MultiGit::Handle.parse('me@mydom.ain') #=> be_a MultiGit::Handle
    #
    def self.parse(string)
      case(string)
      when EMAIL then return new(string, string)
      when NAME_WITH_EMAIL then return new($1,$2)
      else raise ArgumentError, "Unknown handle format: #{string}. Please use either 'user@example.com' or 'User <user@example.com>'"
      end
    end

    DEFAULT = parse("MultiGit #{MultiGit::VERSION} <#{MultiGit::VERSION}@multi.git>")

  end
end
