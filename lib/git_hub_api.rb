require 'httparty'
require 'yaml'
require 'ostruct'
require 'hpricot'

class GitHubApi
  include HTTParty
  
  class Error < StandardError; end
  
  base_uri 'https://github.com'
  
  attr_accessor :user, :api_key
  
  def initialize(user, api_key)
    @user = user
    @api_key = api_key
  end
  
  # Repository Manipulation
  
  def create_repository(details = {})
    name        = details[:name]
    description = details[:description]
    homepage    = details[:homepage]
    is_public   = (!!details.fetch(:public, false) ? 1 : 0)
    if [name, description, homepage].any? { |v| v.blank? }
      raise ArgumentError, "You must provide atleast a name, description and a homepage"
    end
    results = post('repos/create', {
      :name        => name,
      :description => description,
      :homepage    => homepage,
      :public      => is_public
    })
    hash_get(results, "repository")
  end
  
  def repository(name, user = @user)
    results = get("repos/show/#{user}/#{name}")
    repo = hash_get(results, "repository")
    repo ? Repository.new(repo, self) : nil
  end
  
  def repositories(user = @user)
    res = hash_get(get("repos/show/#{user}"), "repositories")
    res.respond_to?(:map) ? res.map { |h| Repository.new(h, self) } : []
  end
  
  class Repository
    
    class SSHPublicKey < Struct.new(:name, :id); end
    
    attr_accessor :name, :api, :attributes, :owner
    
    def initialize(attributes, api)
      @name       = attributes[:name]
      @owner      = attributes[:owner]
      @api        = api
      @attributes = OpenStruct.new(attributes)
    end
    
    def destroy
      token  = api.post("repos/delete/#{@name}")["delete_token"]
      result = api.post("repos/delete/#{@name}", :delete_token => token)
      result.is_a?(Hash) && result["status"] == "deleted"
    end
    
    def private?
      !!@attributes.private
    end
    
    def public?
      !private?
    end
    
    # User Manipulation
    
    def collaborators
      res = api.get("repos/show/#{@owner}/#{@name}/collaborators")
      api.hash_get(res, "collaborators")
    end
    
    def add_collaborator(name)
      return if name.blank?
      res = api.post("repos/collaborators/#{@name}/add/#{name}")
      api.hash_get(res, "collaborators")
    end
    
    def remove_collaborator(name)
      res = api.post("repos/collaborators/#{@name}/remove/#{name}")
      api.hash_get(res, "collaborators")
    end
    
    # Hooks
    
    def hooks
      response = Hpricot(api.get("https://github.com/#{@owner}/#{@name}/edit/hooks").to_s)
      response.search("//input[@name=urls[]]").map { |e| e[:value] }.compact
    end
    
    def hooks=(list)
      list         = [*list].compact.uniq
      query_string = list.map { |u| "urls[]=#{URI.escape(u)}" }.join("&")
      post_url     = "https://github.com/#{@owner}/#{@name}/edit/postreceive_urls"
      api.post(post_url, query_string)
    end
    
    def add_hook(url)
      self.hooks = (hooks + [url])
      hooks.include?(url)
    end
    
    def remove_hook(url)
      self.hooks = (hooks - [url])
      !hooks.include?(url)
    end
    
    # Keys
    
    def keys
      keys = api.hash_get(api.get("repos/keys/#{@name}"), "public_keys")
      return false if keys.nil?
      keys.map { |k| SSHPublicKey.new(k["title"], k["id"]) }
    end
    
    def add_key(title, key)
      result = api.get("repos/key/#{@name}/add", {
        :title => title,
        :key   => key
      })
      keys = api.hash_get(result, "public_keys")
      return false if keys.nil?
      keys.map { |k| SSHPublicKey.new(k["title"], k["id"]) }
    end
    
    def remove_key(key_id)
    end
    
    # Misc. Information
    
    def tags
      api.hash_get(api.get("repos/show/#{@owner}/#{@name}/tags"), "tags")
    end
    
  end
  
  # Methods
  
  def get(path, opts = {})
    self.class.get(full_path_for(path), :query => with_auth(opts))
  end
  
  def post(path, opts = {})
    self.class.post(full_path_for(path), :body => with_auth(opts))
  end
  
  def put(path, opts = {})
    self.class.put(full_path_for(path), :body => with_auth(opts))
  end
  
  def delete(path, opts = {})
    self.class.delete(full_path_for(path), :body => with_auth(opts))
  end
  
  def full_path_for(path, version = 2, format = 'yaml')
    return path if path =~ /^https?\:\/\//i
    File.join("/api/v#{version}/#{format}", path)
  end
  
  def with_auth(opts)
    auth = {
      :login => @user,
      :token => @api_key
    }
    if opts.is_a?(Hash)
      opts.merge(auth)
    else
      params = opts.to_s.strip
      params << "&" if params != ""
      params << auth.to_params
    end
  end
  
  def check_results!(res)
    if res.is_a?(Hash) && res["error"].present?
      error_msg = res["error"].to_a.map { |h| h["error"] }.join(", ")
      raise Error, error_msg
    end
  end
  
  def hash_get(h, k)
    check_results!(h)
    h.is_a?(Hash) && h[k]
  end
  
  def self.default
    return @@default if defined?(@@default) && @@default.present?
    user  = `git config --global github.user`.strip
    token = `git config --global github.token`.strip
    @@default = self.new(user, token)
  end
  
end