require 'multi_git/walkable'
describe MultiGit::Walkable, walkable: true do

  let(:walker){
    walker = double('walker')
    walker.extend(MultiGit::Walkable)
    walker
  }

  it "walks pre-order" do
    walker.should_receive(:walk_pre)
    walker.walk do end
  end

  it "walks post-order" do
    walker.should_receive(:walk_post)
    walker.walk(:post) do end
  end

  it "walks leafs" do
    walker.should_receive(:walk_leaves)
    walker.walk(:leaves) do end
  end

  it "barfs for other walkmodes" do
    expect{
      walker.walk(Object.new)
    }.to raise_error(ArgumentError)
  end

end
