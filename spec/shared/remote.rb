describe '#remote', remote: true do

  let(:repository){ subject.open(tempdir, init: true) }

  context 'by url' do

    let(:remote){ repository.remote('git://github.com/git/git.git') }

    it 'works' do
      remote.should be_a(MultiGit::Remote)
    end

    it 'has the correct fetch_url' do
      remote.fetch_urls.should == ['git://github.com/git/git.git']
    end

    it 'has the correct push_url' do
      remote.push_urls.should == ['git://github.com/git/git.git']
    end
  end

  context 'by existing name' do

    before(:each) do
      `cd #{tempdir}; git init --bare ; git remote add origin git://github.com/git/git.git`
    end

    let(:remote){ repository.remote('origin') }

    it 'works' do
      remote.should be_a(MultiGit::Remote::Persistent)
    end

    it 'has the correct name' do
      remote.name.should == 'origin'
    end

    it 'has the correct fetch_url' do
      remote.fetch_urls.should == ['git://github.com/git/git.git']
    end

    it 'has the correct push_url' do
      remote.push_urls.should == ['git://github.com/git/git.git']
    end
  end

end

describe '#remote#fetch', remote: true do

  let(:repository){ subject.open(tempdir, init: true) }

  let(:remote_tempdir){ Dir.mktmpdir }

  before(:each) do
    remote = MultiGit.open(remote_tempdir, init:true, bare:true)
    remote.branch('master').update do
      MultiGit::Commit::Builder.new do
        tree.file "foo", "bar"
        at Time.utc(2010,1,1,12,0,0)
        by 'example@multi.git'
      end
    end
    remote['HEAD'].update do
      remote.branch('master')
    end
  end

  after(:each) do
    FileUtils.rm_rf(remote_tempdir)
  end

  context 'by url' do

    let(:remote){ repository.remote(remote_tempdir) }

    it "can fetch stuff" do
      remote.fetch('master:foo/master')
      repository.branch('foo/master').target.oid.should == '20fde9a8ac86cd9e35b147b3f1460798074d0c57'
    end

  end

  context 'by existing name' do

    before(:each) do
      `cd #{tempdir}; git init --bare ; git remote add origin #{remote_tempdir}`
    end

    let(:remote){ repository.remote('origin') }

    it "can fetch stuff" do
      remote.fetch('master')
      repository.branch('origin/master').target.oid.should == '20fde9a8ac86cd9e35b147b3f1460798074d0c57'
    end

  end

end

describe '#remote#push', remote: true do

  let(:repository){ subject.open(tempdir) }

  let(:remote_tempdir){ Dir.mktmpdir }
  let(:remote_repository){ MultiGit.open( remote_tempdir ) }

  before(:each) do
    MultiGit.open(remote_tempdir, init:true, bare:true)
    MultiGit.open(tempdir, init: true, bare: true).branch('master').update do
      MultiGit::Commit::Builder.new do
        tree.file "foo", "bar"
        at Time.utc(2010,1,1,12,0,0)
        by 'example@multi.git'
      end
    end
  end

  after(:each) do
    FileUtils.rm_rf(remote_tempdir)
  end

  context 'by url' do

    let(:remote){ repository.remote(remote_tempdir) }

    it "can push stuff" do
      remote.push('master:master')
      remote_repository.branch('master').target.oid.should == '20fde9a8ac86cd9e35b147b3f1460798074d0c57'
    end

  end

  context 'by existing name' do

    before(:each) do
      `cd #{tempdir}; git init --bare ; git remote add origin #{remote_tempdir}`
    end

    let(:remote){ repository.remote('origin') }

    it "can push stuff" do
      remote.push('master')
      remote_repository.branch('master').target.oid.should == '20fde9a8ac86cd9e35b147b3f1460798074d0c57'
    end

  end

end
