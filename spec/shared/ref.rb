describe '#ref', ref: true do

  def update_master
    `cd #{tempdir}
OID=$(echo -n "foo" | env -i git hash-object -w -t blob --stdin )
TOID=$(echo "100644 blob $OID\tfoo" | env -i git mktree)
COID=$(echo "msg" | env -i GIT_COMMITTER_NAME=multi_git GIT_COMMITTER_EMAIL=info@multi.git GIT_AUTHOR_NAME=multi_git GIT_AUTHOR_EMAIL=info@multi.git git commit-tree $TOID)
env -i git update-ref refs/heads/master $COID 2>&1`
  end

  def commit_builder(*args)
    MultiGit::Commit::Builder.new(*args) do
      message "foo"
      by 'info@multi.git'
      tree['foo'] = 'bar'
      at Time.utc(2012,1,1,12,0,0)
    end
  end

  blk = proc do
    before(:each) do
      `mkdir -p #{tempdir}
cd #{tempdir}
env -i git init --bare . > /dev/null
OID=$(echo -n "foo" | env -i git hash-object -w -t blob --stdin )
TOID=$(echo "100644 blob $OID\tfoo" | env -i git mktree)
COID=$(echo "msg" | env -i GIT_COMMITTER_NAME=multi_git GIT_COMMITTER_EMAIL=info@multi.git 'GIT_COMMITTER_DATE=2005-04-07T22:13:13 +0200' GIT_AUTHOR_NAME=multi_git GIT_AUTHOR_EMAIL=info@multi.git 'GIT_AUTHOR_DATE=2005-04-07T22:13:13 +0200' git commit-tree $TOID)
env -i git update-ref refs/heads/master $COID`
    end

    let(:repository){ subject.open(tempdir) }

    it "reads the commit" do
      commit = repository.read('refs/heads/master')
      commit.parents.should == []
      commit.tree.should be_a(MultiGit::Tree)
      commit.message.should == "msg\n"
    end

    it "forwards certain methods to the tree" do
      commit = repository.read('master')
      commit['foo'].should be_a(MultiGit::File)
      (commit / 'foo' ).should be_a(MultiGit::File)
    end

    it "allows building a child commit" do
      commit = repository.read('master')
      child = MultiGit::Commit::Builder.new( commit )
      child.tree['foo'].should be_a(MultiGit::File::Builder)
      child.parents[0].should == commit
      child.message = 'foo'
      handle = child.author = child.committer = MultiGit::Handle.new('multi_git','info@multi.git')
      child.time = child.commit_time = Time.utc(2010,1,1,12,0,0)
      nu = child >> repository
      nu.committer.should == handle
      nu.author.should == handle
      nu.time.should == Time.utc(2010,1,1,12,0,0)
      nu.commit_time.should == Time.utc(2010,1,1,12,0,0)
      nu.message.should == 'foo'
      nu.oid.should == "04cd8dc458e3a6f98cd498b18f905c6a4fd30778"
    end

    it "handles refs" do
      head = repository.ref('refs/heads/master')
      head.target.should == repository.read('refs/heads/master')
      head.name.should == 'refs/heads/master'
      head.should be_exists
      head.should_not be_symbolic
    end

    it "refuses wrong refs" do
      expect{
        repository.ref('master')
      }.to raise_error(MultiGit::Error::InvalidReferenceName)
    end

    it "handles non-existing refs" do
      head = repository.ref('refs/heads/foo')
      head.target.should be_nil
      head.should_not be_exists
      head.name.should == 'refs/heads/foo'
    end

    it "creates non-existing refs" do
      head = repository.ref('refs/heads/foo')
      head.update do |target|
        target.should be_nil
        commit_builder target
      end
      head.reload.target.oid.should == '553bfb16f88e60e71f527f91433aa7282066a332'
    end

    it "creates non-existing refs pessimstically" do
      head = repository.ref('refs/heads/foo')
      head.update(:pessimistic) do |target|
        target.should be_nil
        commit_builder target
      end
      head.reload.target.oid.should == '553bfb16f88e60e71f527f91433aa7282066a332'
    end

    it "can update refs directly" do
      head = repository.ref('refs/heads/master')
      head.update( commit_builder head.target )
      repository.ref('refs/heads/master').target.oid.should == 'a00f6588c95cf264fb946480494c418371105a26'
    end

    it "can lock refs optimistic" do
      head = repository.ref('refs/heads/master')
      head.update do |target|
        commit_builder target
      end
      repository.ref('refs/heads/master').target.oid.should == 'a00f6588c95cf264fb946480494c418371105a26'
    end

    it "can lock refs pessimistic" do
      head = repository.ref('refs/heads/master')
      head.update(:pessimistic) do |target|
        commit_builder target
      end
      repository.ref('refs/heads/master').target.oid.should == 'a00f6588c95cf264fb946480494c418371105a26'
    end

    it "barfs when a ref gets updated during optimistic update" do
      head = repository.ref('refs/heads/master')
      expect{
        head.update do |target|
          update_master
          commit_builder target
        end
      }.to raise_error(MultiGit::Error::ConcurrentRefUpdate)
    end

    it "lets others barf when a ref gets updated during pessimistic update" do
      head = repository.ref('refs/heads/master')
      head.update(:pessimistic) do |target|
        update_master.should =~ /fatal: Unable to create '.+\.lock': File exists./
        $?.exitstatus.should == 128
        commit_builder target
      end
    end

    it "just overwrites refs with reckless update" do
      head = repository.ref('refs/heads/master')
      head.update(:reckless) do |target|
        update_master
        commit_builder target
      end
      repository.ref('refs/heads/master').target.oid.should == 'a00f6588c95cf264fb946480494c418371105a26'
    end

    it "delete refs optimistic" do
      head = repository.ref('refs/heads/master')
      head.update do |target|
        nil
      end
      repository.ref('refs/heads/master').target.should be_nil
    end

    it "can delete refs pessimistic" do
      head = repository.ref('refs/heads/master')
      head.update(:pessimistic) do |target|
        nil
      end
      repository.ref('refs/heads/master').target.should be_nil
    end

    it "can use the commit dsl" do
      master = repository.branch('master')
      master = master.commit do
        tree['bar'] = 'baz'
      end
      master['bar'].content.should == 'baz'
    end

    it "can set symbolic refs" do
      head = repository.ref('HEAD')
      master = repository.ref('refs/heads/master')
      r = head.update do
        master
      end
      r.target.should == master
    end

    it "can set symbolic refs pessimistic" do
      head = repository.ref('HEAD')
      master = repository.ref('refs/heads/master')
      r = head.update(:pessimistic) do
        master
      end
      r.target.should == master
    end

    it "can detach symbolic refs" do
      head = repository.ref('HEAD')
      target = repository.ref('refs/heads/master').target
      head.update{ target }
      repository.ref('HEAD').target.should == target
    end

  end

  context "with a repository containing a commit", commit:true, &blk
  context "with a repository containing a commit (packed-ref)", commit:true do
    instance_eval &blk
    before(:each) do
      `cd #{tempdir}; git gc 2> /dev/null`
    end
  end
end
