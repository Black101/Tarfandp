require 'fileutils'
require 'tmpdir'
require 'tempfile'
require 'timeout'
shared_examples "a MultiGit blob instance" do

  it "is recognized as a Git::Blob" do
    expect(make_blob("Use all the git!")).to be_a(MultiGit::Blob)
  end

  it "is readeable" do
    expect(make_blob("Use all the git!").content).to be_a(String)
  end

  it "has frozen content" do
    expect(make_blob("Use all the git!").content).to be_frozen
  end

  it "returns different ios" do
    blob = make_blob("Use all the git!")
    io1 = blob.to_io
    expect(io1.read).to eql "Use all the git!"
    expect(io1.read).to eql ""
    io2 = blob.to_io
    expect(io2.read).to eql "Use all the git!"
    expect(io1.read).to eql ""
  end

  it "returns rewindeable ios" do
    blob = make_blob("Use all the git!")
    io = blob.to_io
    expect(io.read).to eql "Use all the git!"
    expect(io.read).to eql ""
    io.rewind
    expect(io.read).to eql "Use all the git!"
    expect(io.read).to eql ""
  end

  it "has the correct size" do
    blob = make_blob("Use all the git!")
    expect(blob.bytesize).to eql 16
  end
end

shared_examples "an empty repository" do

  it "can add a blob from string" do
    result = repository.write("Blobs", :blob)
    expect(result).to be_a(MultiGit::Blob)
    expect(result.oid).to eql 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  end

  it "behaves nice if an object is already present" do
    repository.write("Blobs", :blob)
    result = repository.write("Blobs", :blob)
    expect(result).to be_a(MultiGit::Blob)
    expect(result.oid).to eql 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  end

  it "can add a blob from an IO ducktype" do
    io = double("io")
    expect(io).to receive(:read).and_return "Blobs"
    result = repository.write(io, :blob)
    expect(result).to be_a(MultiGit::Blob)
    expect(result.oid).to eql 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  end

  it "can add a blob from a file ducktype" do
  begin
    tmpfile = Tempfile.new('multi_git')
    tmpfile.write "Blobs"
    tmpfile.rewind
    result = repository.write(tmpfile, :blob)
    expect(result).to be_a(MultiGit::Blob)
    expect(result.oid).to eql 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  ensure
    File.unlink tmpfile.path if tmpfile
  end
  end

  it "can add a blob from a blob ducktype" do
    blob = double("blob")
    blob.extend(MultiGit::Object)
    blob.extend(MultiGit::Blob)
    blob.stub(:oid){ 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a' }
    expect(blob).to receive(:to_io).and_return StringIO.new("Blobs")
    result = repository.write(blob)
    expect(result).to be_a(MultiGit::Blob)
    expect(result.oid).to eql 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  end

  it "short-circuts adding an already present blob" do
    blob = double("blob")
    blob.extend(MultiGit::Object)
    blob.extend(MultiGit::Blob)
    blob.stub(:oid){ 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a' }
    expect(blob).not_to receive(:read)
    repository.write("Blobs")
    result = repository.write(blob)
    expect(result).to be_a(MultiGit::Blob)
    expect(result.oid).to eql 'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  end

  it "can add a File::Builder" do
    fb = MultiGit::File::Builder.new(nil, "a", "Blobs")
    result = repository.write(fb)
    expect(result).to be_a(MultiGit::File)
    expect(result.name).to eql 'a'
    expect(result.oid).to eql  'b4abd6f716fef3c1a4e69f37bd591d9e4c197a4a'
  end

  it "a File::Builder compares equal to the file it created" do
    fb = MultiGit::File::Builder.new(nil, "a", "Blobs")
    expect( repository.write(fb) ).to eq fb
  end

  it "a File::Builder compares equal to the file it created ( other direction )" do
    fb = MultiGit::File::Builder.new(nil, "a", "Blobs")
    expect( fb ).to eq repository.write(fb)
  end

  it "can add a Tree::Builder" do
    tb = MultiGit::Tree::Builder.new do
      file "a", "b"
      directory "c" do
        file "d", "e"
      end
    end
    result = repository.write(tb)
    expect(result).to be_a(MultiGit::Tree)
    expect(result['a']).to be_a(MultiGit::File)
    expect(result['c']).to be_a(MultiGit::Directory)
    expect(result['c/d']).to be_a(MultiGit::File)
    expect(result.oid).to eql  'b490aa5179132fe8ea44df539cf8ede23d9cc5e2'
  end

  it "can add a Tree::Builder with executeables" do
    tb = MultiGit::Tree::Builder.new do
      executeable "a", "b"
      directory "c" do
        executeable "d", "e"
      end
    end
    result = repository.write(tb)
    expect(result).to be_a(MultiGit::Tree)
    expect(result['a']).to be_a(MultiGit::Executeable)
    expect(result['c']).to be_a(MultiGit::Directory)
    expect(result['c/d']).to be_a(MultiGit::Executeable)
    expect(result.oid).to eql  'd65bc69b6facdb9c389c3b6dc1c2a0d2115ad076'
  end

  it "can read a previously added blob" do
    inserted = repository.write("Blobs", :blob)
    object = repository.read(inserted.oid)
    expect(object).to be_a(MultiGit::Blob)
    expect(object.content).to eql "Blobs"
    expect(object.bytesize).to eql 5
    expect(object.oid).to eql inserted.oid
  end

  it "can parse a sha1-prefix to the full oid" do
    inserted = repository.write("Blobs", :blob)
    expect(repository.parse(inserted.oid[0..10])).to eql inserted.oid
  end

  it "barfs when trying to read an non-existing oid" do
    expect{
      repository.read("123456789abcdef")
    }.to raise_error(MultiGit::Error::InvalidReference)
  end

  it "can add a simple tree with #make_tree", :make_tree => true do
    oida = repository.write("a").oid
    oidb = repository.write("b").oid
    oidc = repository.write("c").oid
    tree = repository.make_tree([
                                  ['c', 0100644, oidc],
                                  ['a', 0100644, oida],
                                  ['b', 0100644, oidb]
                                ])
    expect(tree.oid).to eql "24e88cb96c396400000ef706d1ca1ed9a88251aa"
  end

  it "can add a nested tree with #make_tree", :make_tree => true do
    oida = repository.write("a").oid
    inner_tree = repository.make_tree([
                                  ['a', 0100644, oida],
                                ])
    tree = repository.make_tree([
                                ['tree', 040000, inner_tree.oid]])
    expect(tree.oid).to eql "ea743e8d65faf4e126f0d1c4629d1083a89ca6af"
  end

end

shared_examples "a MultiGit backend" do

  let(:tempdir) do
    Dir.mktmpdir('multi_git')
  end

  after(:each) do
    FileUtils.rm_rf( tempdir )
  end

  def jgit?
    described_class == MultiGit::JGitBackend
  end

  context "with an empty directory" do

    it "barfs" do
      expect{
        subject.open(tempdir)
      }.to raise_error(MultiGit::Error::NotARepository)
    end

    it "inits a repository with :init" do
      expect(subject.open(tempdir, :init => true)).to be_a(MultiGit::Repository)
      expect(File.exists?(File.join(tempdir,'.git'))).to be_true
    end

    it "inits a bare repository with :init and :bare" do
      expect(subject.open(tempdir, :init => true, :bare => true)).to be_a(MultiGit::Repository)
      expect(File.exists?(File.join(tempdir,'refs'))).to be_true
    end
  end

  context "with an empty repository" do

    before(:each) do
      `env -i git init #{tempdir}`
    end

    let(:repository) do
      subject.open(tempdir)
    end

    it "opens the repo without options" do
      repo = subject.open(tempdir)
      expect(repo).to be_a(MultiGit::Repository)
      expect(repo).to_not be_bare
      expect(repo.git_dir).to eql File.join(tempdir, '.git')
      expect(repo.git_work_tree).to eql tempdir
    end

    it "opens the repo with :bare => false option" do
      repo = subject.open(tempdir, bare: false)
      expect(repo).to be_a(MultiGit::Repository)
      expect(repo).to_not be_bare
    end

    it "opens the repo with :bare => true option" do
      pending
      repo = subject.open(tempdir, bare: true)
      expect(repo).to be_a(MultiGit::Repository)
      expect(repo).to be_bare
    end

    it_behaves_like "an empty repository"

  end

  context "with an emtpy bare repository" do

    before(:each) do
      `env -i git init --bare #{tempdir}`
    end

    let(:repository) do
      subject.open(tempdir)
    end

    it "opens the repo without options" do
      repo = subject.open(tempdir)
      expect(repo).to be_a(MultiGit::Repository)
      expect(repo.git_dir).to eql tempdir
      expect(repo.git_work_tree).to be_nil
      expect(repo).to be_bare
    end

    it "opens the repo with :bare => true option" do
      repo = subject.open(tempdir, bare: true)
      expect(repo).to be_a(MultiGit::Repository)
    end

    it "barfs with :bare => false option" do
      expect{
        subject.open(tempdir, bare: false)
      }.to raise_error(MultiGit::Error::RepositoryBare)
    end

    it_behaves_like "an empty repository"

  end

  context "blob implementation" do

    let(:repository) do
      subject.open(tempdir, init: true)
    end

    def make_blob(content)
      obj = repository.write(content)
      repository.read(obj.oid)
    end

    it_behaves_like "a MultiGit blob instance"

  end

  context "with a repository containing a tiny tree", :tree => true do

    before(:each) do
      `mkdir -p #{tempdir}
cd #{tempdir}
env -i git init --bare . > /dev/null
OID=$(echo "foo" | env -i git hash-object -w -t blob --stdin )
TOID=$(echo "100644 blob $OID\tbar" | env -i git mktree)
echo "100644 blob $OID\tbar\n040000 tree $TOID\tfoo" | env -i git mktree > /dev/null`
    end

    let(:tree_oid) do
      "95b3dc37df875dfdced5157fa4330d55e6597304"
    end

    let(:tree) do
      tree = repository.read(tree_oid)
    end

    let(:repository) do
      subject.open(tempdir)
    end

    it "reads the tree" do
      tree = repository.read(tree_oid)
      expect(tree).to be_a(MultiGit::Tree)
    end

    it "knows the size" do
      tree = repository.read(tree_oid)
      expect(tree.size).to eql 2
    end

    it "iterates over the tree" do
      tree = repository.read(tree_oid)
      expect{|yld|
        tree.each(&yld)
      }.to yield_successive_args(
        MultiGit::File,
        MultiGit::Directory)
    end

    it "has the right size" do
      expect(tree.size).to eql 2
    end

    it "allows treating the tree as io" do
      begin
        expect(tree.to_io.read.bytes.to_a).to eql [49, 48, 48, 54, 52, 52, 32, 98, 97, 114, 0, 37, 124, 197, 100, 44, 177, 160, 84, 240, 140, 200, 63, 45, 148, 62, 86, 253, 62, 190, 153, 52, 48, 48, 48, 48, 32, 102, 111, 111, 0, 239, 188, 23, 230, 30, 116, 109, 173, 92, 131, 75, 203, 148, 134, 155, 166, 107, 98, 100, 249]
      rescue NoMethodError => e
        if RUBY_ENGINE == 'rbx' && e.message == "undefined method `ascii?' on nil:NilClass."
          pending "chomp is borked in rubinius"
        end
        raise
      end
    end

    it "allows treating the tree as io" do
      expect(tree.bytesize).to eql 61
    end

    describe "#[]" do

      it "allows accessing entries by name" do
        expect(tree['foo']).to be_a(MultiGit::Directory)
      end

      it "allows accessing nested entries" do
        expect(tree['foo/bar']).to be_a(MultiGit::File)
      end

      it "raises an error for an object" do
        expect{ tree[Object.new] }.to raise_error(ArgumentError, /Expected a String/)
      end

    end

    describe "#key?" do
      it "confirms correctly for names" do
        expect(tree.key?('foo')).to be_true
      end

      it "declines correctly for names" do
        expect(tree.key?('blub')).to be_false
      end

      it "raises an error for objects" do
        expect{ tree.key? Object.new }.to raise_error(ArgumentError, /Expected a String/)
      end
    end

    describe '#/' do

      it "allows accessing entries with a slash" do
        expect((tree / 'foo')).to be_a(MultiGit::Directory)
      end

      it "sets the correct parent" do
        expect( (tree / 'foo').parent ).to be tree
      end

      it "allows accessing nested entries with a slash" do
        expect((tree / 'foo/bar')).to be_a(MultiGit::File)
      end

      it "raises an error for missing entry offset" do
        expect{ tree / "blub" }.to raise_error(MultiGit::Error::InvalidTraversal, /doesn't contain an entry named "blub"/)
      end

      it "traverses to the parent tree" do
        expect(tree / 'foo' / '..').to be tree
      end

      it "raises an error if the parent tree is unknown" do
        expect{
          tree / '..'
        }.to raise_error(MultiGit::Error::InvalidTraversal, /Can't traverse to parent of/)
      end

    end

    describe '#to_builder' do

      it "creates a builder" do
        expect(tree.to_builder).to be_a(MultiGit::Builder)
      end

      it "contains all entries from the original tree" do
        b = tree.to_builder
        expect(b.size).to eql 2
        expect(b['foo']).to be_a(MultiGit::Directory::Builder)
        expect(b['bar']).to be_a(MultiGit::File::Builder)
      end

      it "contains entries with correct parent" do
        b = tree.to_builder
        b.each do |e|
          expect(e.parent).to eql b
        end
      end

      it "allows deleting keys" do
        b = tree.to_builder
        b.delete('bar')
        expect(b.size).to eql 1
        expect(b.entry('bar')).to be_nil
        new_tree = b >> repository
        expect(new_tree.oid).to eql "d4ab49e21a8683faa04acb23ba7aa3c1840509a0"
      end

      it "allows deleting nested keys" do
        b = tree.to_builder
        b.delete('foo/bar')
        expect(b['foo'].size).to eql 0
        expect(b.entry('foo/bar')).to be_nil
        new_tree = b >> repository
        expect(new_tree.oid).to eql "907fcde7d35ba60b853b4d78465d2cc36824ec08"
      end

    end

    describe '#walk', :walk => true do

      it "walks in pre-order" do
        expect{|yld|
          tree.walk(&yld)
        }.to yield_successive_args(
                          Something[class: MultiGit::File, path: 'bar'],
                          Something[class: MultiGit::Directory, path: 'foo'],
                          Something[class: MultiGit::File, path: 'foo/bar']
                                  )
      end

      it "walks in post-order" do
        expect{|yld|
          tree.walk(:post, &yld)
        }.to yield_successive_args(
                          Something[class: MultiGit::File, path: 'bar'],
                          Something[class: MultiGit::File, path: 'foo/bar'],
                          Something[class: MultiGit::Directory, path: 'foo']
                                  )
      end

      it "walks in leaves-order" do
        expect{|yld|
          tree.walk(:leaves, &yld)
        }.to yield_successive_args(
                          Something[class: MultiGit::File, path: 'bar'],
                          Something[class: MultiGit::File, path: 'foo/bar'],
                                  )
      end
    end

    describe "#glob", :glob => true do

      it "finds the toplevel directory with dotmatch" do
        expect{|yld|
          tree.glob('*', File::FNM_DOTMATCH, &yld)
        }.to yield_successive_args(tree,
                                   Something[class: MultiGit::File, path: 'bar'],
                                   Something[class: MultiGit::Directory, path: 'foo'] )
      end

      it "finds the directory but not it's children" do
        expect{|yld|
          tree.glob('f*', &yld)
        }.to yield_successive_args(Something[class: MultiGit::Directory, path: 'foo'] )
      end

      it "finds the files with recursive directory matching" do
        expect{|yld|
          tree.glob('**/bar', &yld)
        }.to yield_successive_args(Something[class: MultiGit::File, path: 'bar'],
                                   Something[class: MultiGit::File, path: 'foo/bar'])
      end
    end

  end

  context "with a repository containing a simple symlink", :tree => true, :symlink => true do

    before(:each) do
      `mkdir -p #{tempdir}
cd #{tempdir}
env -i git init --bare . > /dev/null
OID=$(echo -n "foo" | env -i git hash-object -w -t blob --stdin )
echo "120000 blob $OID\tbar\n100644 blob $OID\tfoo" | env -i git mktree`
    end

    let(:tree_oid){ "b1210985da34bd8a8d55502b3891fbe5c9f2d7b7" }

    let(:repository){ subject.open(tempdir) }

    let(:tree){ repository.read(tree_oid) }

    it "reads the symlink" do
      expect(tree['bar', follow: false]).to be_a(MultiGit::Symlink)
    end

    it "resolves the symlink" do
      target = tree['bar', follow: false].resolve 
      expect(target).to be_a(MultiGit::File)
    end

    it "automatically resolves the symlink" do
      expect(tree['bar']).to be_a(MultiGit::File)
    end

    it "gives a useful error when trying to traverse into the file" do
      expect{
        tree['bar/foo']
      }.to raise_error(MultiGit::Error::InvalidTraversal)
    end

    describe '#to_builder' do

      it "gives a builder" do
        b = tree.to_builder
        expect(b['bar', follow: false]).to be_a(MultiGit::Symlink::Builder)
      end

      it "gives a builder" do
        b = tree.to_builder
        expect(b['bar']).to be_a(MultiGit::File::Builder)
      end

      it "allows setting the target" do
        b = tree.to_builder
        b.file('buz','Zup')
        b['bar', follow: false].target = "buz"
        expect(b['bar'].name).to eql 'buz'
      end

    end

  end

  context "with a repository containing a self-referential symlink", :tree => true, :symlink => true do

    before(:each) do
      `mkdir -p #{tempdir}
cd #{tempdir}
env -i git init --bare . > /dev/null
OID=$(echo -n "foo" | env -i git hash-object -w -t blob --stdin )
echo "120000 blob $OID\tfoo" | env -i git mktree`
    end

    let(:tree_oid){ "12f0253e71b89b95a92128be2844ff6a0c9e6a55" }

    let(:repository){ subject.open(tempdir) }

    let(:tree){ repository.read(tree_oid) }

    it "raises an error if we try to traverse it" do
      # This could loop forever, so ...
      Timeout.timeout(2) do
        expect{
          tree['foo']
        }.to raise_error(MultiGit::Error::CyclicSymlink)
      end
    end

    it "allows traverse it without follow" do
      # This could loop forever, so ...
      Timeout.timeout(2) do
        expect(tree['foo', follow: false]).to be_a(MultiGit::Symlink)
      end
    end

    it "raises an error if we try to resolve it" do
      # This could loop forever, so ...
      Timeout.timeout(2) do
        expect{
          tree['foo', follow: false].resolve
        }.to raise_error(MultiGit::Error::CyclicSymlink)
      end
    end

  end

  context "#each_branch" do

    before(:each) do
      `mkdir -p #{tempdir}`
      build = MultiGit::Commit::Builder.new do
        tree['foo'] = 'bar'
      end
      commit = repository << build
      repository.branch('master').update{ commit }
      repository.branch('foo').update{ commit }
      repository.branch('origin/bar').update{ commit }
    end

    let(:repository){ subject.open(tempdir, init: true) }

    it "lists all branches" do
      expect{|yld|
        repository.each_branch(&yld)
      }.to yield_successive_args(MultiGit::Ref,MultiGit::Ref,MultiGit::Ref)
    end

    it "filters by regexp" do
      expect{|yld|
        repository.each_branch(/\Afoo\z/, &yld)
      }.to yield_successive_args(MultiGit::Ref)
    end

    it "lists local branches" do
      expect{|yld|
        repository.each_branch(:local, &yld)
      }.to yield_successive_args(MultiGit::Ref,MultiGit::Ref)
    end

    it "lists remote branches" do
      expect{|yld|
        repository.each_branch(:remote, &yld)
      }.to yield_successive_args(MultiGit::Ref)
    end

  end

  context '#each_tag', tag: true do

    before(:each) do
      `mkdir -p #{tempdir}`
      build = MultiGit::Commit::Builder.new do
        tree['foo'] = 'bar'
      end
      commit = repository << build
      repository.tag('master').update{ commit }
      repository.tag('foo').update{ commit }
    end

    let(:repository){ subject.open(tempdir, init: true) }

    it "lists all tags" do
      expect{|yld|
        repository.each_tag(&yld)
      }.to yield_successive_args(MultiGit::Ref,MultiGit::Ref)
    end

  end

  context 'executeables', executeable:true do

     before(:each) do
      `mkdir -p #{tempdir}`
      build = MultiGit::Commit::Builder.new do
        tree.executeable 'foo', 'bar'
      end
      commit = repository << build
      repository.branch('master').update( commit )
    end

    let(:repository){ subject.open(tempdir, init: true) }

    it 'reads the executeable correctly' do
      commit = repository.branch('master').target
      expect(commit.tree['foo']).to be_a MultiGit::Executeable
    end

  end

  def self.embrace(file)
    file = File.expand_path(file, File.dirname(__FILE__))
    class_eval(IO.read(file), file, 0)
  end

  embrace 'shared/ref.rb'
  embrace 'shared/config.rb'
  embrace 'shared/remote.rb'

end
