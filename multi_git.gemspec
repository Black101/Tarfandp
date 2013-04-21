require File.join(File.dirname(__FILE__), 'lib', 'multi_git', 'version')
Gem::Specification.new do |gem|
  gem.name    = 'multi_git'
  gem.version = MultiGit::VERSION
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "Use all the gits"

  gem.authors  = ['Hannes Georg']
  gem.email    = 'hannes.georg@googlemail.com'
  gem.homepage = 'https://github.com/hannesg/ridley-git'

  # ensure the gem is built out of versioned files
  gem.files = Dir['lib/**/*'] & `git ls-files -z`.split("\0")

  gem.requirements << "jar 'org.eclipse.jgit:org.eclipse.jgit'"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "simplecov"
end
