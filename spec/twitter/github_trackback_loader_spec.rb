require File.join(File.dirname(File.expand_path(__FILE__)), '..', 'spec_helper')

describe Grapevine::Twitter::GitHubTrackbackLoader do
  ##############################################################################
  # Setup
  ##############################################################################

  before do
    DataMapper.auto_migrate!
    FakeWeb.allow_net_connect = false
    @loader = Grapevine::Twitter::GitHubTrackbackLoader.new
    @loader.name = 'my-github-loader'
    @fixtures_dir = File.join(File.dirname(File.expand_path(__FILE__)), '..', 'fixtures')
  end

  after do
    FakeWeb.clean_registry
  end

  def register_topsy_search_uri(filename, options={})
    options = {:page=>1, :perpage=>10, :site=>'github.com'}.merge(options)
    FakeWeb.register_uri(:get, "http://otter.topsy.com/search.json?page=#{options[:page]}&perpage=#{options[:perpage]}&window=realtime&q=#{CGI.escape(options[:site])}", :response => IO.read("#{@fixtures_dir}/topsy/search/#{filename}"))
  end

  def register_github_user_uri(username, filename, options={})
    options = {}.merge(options)
    FakeWeb.register_uri(:get, "https://github.com/api/v2/yaml/user/show/#{username}", :response => IO.read("#{@fixtures_dir}/github/users/#{filename}"))
  end

  def register_github_repo_uri(username, repo_name, filename, options={})
    options = {}.merge(options)
    FakeWeb.register_uri(:get, "https://github.com/api/v2/yaml/repos/show/#{username}/#{repo_name}", :response => IO.read("#{@fixtures_dir}/github/repos/#{filename}"))
  end

  def register_github_repo_language_uri(username, repo_name, filename, options={})
    options = {}.merge(options)
    FakeWeb.register_uri(:get, "https://github.com/api/v2/yaml/repos/show/#{username}/#{repo_name}/languages", :response => IO.read("#{@fixtures_dir}/github/repos/languages/#{filename}"))
  end


  ##############################################################################
  # Tests
  ##############################################################################

  it 'should error when loading without site defined' do
    @loader.site = nil
    lambda {@loader.load()}.should raise_error('Cannot load trackbacks without a site defined')
  end

  it 'should return a single trackback with a GitHub project root URL' do
    register_topsy_search_uri('site_github_single')
    
    @loader.load()
    
    Message.all.length.should == 1
    message = Message.first
    message.source.should    == 'my-github-loader'
    message.source_id.should == '23909517578211328'
    message.author.should    == 'coplusk'
    message.url.should       == 'https://github.com/tomwaddington/suggestedshare/commit/1e4117f001d224cd15039ff030bc39b105f24a13'
  end

  it 'should filter out non-project URLs' do
    register_topsy_search_uri('site_github_nonproject')
    
    @loader.load()
    Message.all.length.should == 0
  end


  #####################################
  # Aggregation
  #####################################

  it 'should create topic from message' do
    register_topsy_search_uri('site_github_single')
    register_github_user_uri('tomwaddington', 'tomwaddington')
    register_github_repo_uri('tomwaddington', 'suggestedshare', 'tomwaddington_suggestedshare')
    register_github_repo_language_uri('tomwaddington', 'suggestedshare', 'tomwaddington_suggestedshare')
    @loader.load()
    
    Topic.all.length.should == 1
    topic = Topic.first
    topic.source.should == 'my-github-loader'
    topic.name.should == 'suggestedshare'
    topic.description.should == 'Share content on Facebook with like-minded friends'
    topic.url.should == 'https://github.com/tomwaddington/suggestedshare'
    topic.tags.length.should == 1
    topic.tags[0].type.should == 'language'
    topic.tags[0].value.should == 'javascript'
  end
end
