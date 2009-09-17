require 'gitauth'
require 'digest/sha2'

dir = Pathname.new(__FILE__).dirname.dirname
$:.unshift(dir) unless $:.include?(dir)

require 'git_hub_api'

module GitAuth
  class GitHubMirror
    include GitAuth::Loggable
    
    Project = Struct.new(:name, :github_clone_url, :repository, :github)
    
    VERSION = [0, 0, 3, 0]
    
    def initialize(username, token)
      @api = GitHubApi.new(username, token)
    end
    
    def projects
      @projects ||= @api.repositories.map do |repository|
        local_repo = GitAuth::Repo.get(repository.name)
        Project.new(repository.name, github_url_for_repo(repository), local_repo, repository)
      end
    end
    
    def mirror!(p)
      mirrored?(p) ? update!(p) : clone!(p) 
    end
    
    def update!(p)
      return unless p.repository
      Dir.chdir(p.repository.real_path) do
        GitAuth.run "git fetch origin --force"
      end
    end
    
    def clone!(p)
      if repository = GitAuth::Repo.create(p.name, "#{p.name}.git")
        FileUtils.rm_rf(repository.real_path)
        path = repository.real_path
        Dir.chdir(File.dirname(path)) do
          GitAuth.run "git clone --mirror #{p.github_clone_url} #{File.basename(path)}"
        end
        p.repository = repository
      else
        raise "Error creating local mirror of repository '#{p.name}'"
      end
    end
    
    def mirror_all
      logger.info "Mirroring all projects"
      projects.each do |project|
        logger.info "Mirroring for #{project.name} (#{project.github_clone_url})"
        mirror!(project)
      end
    end
    
    def mirror_deploy_keys(p)
      if p.github.private?
        p.github.keys.each do |key|
          u = user_for_key(key)
          p.repository.readable_by(u) 
        end
      end
    end
    
    def mirror_user_keys
      users = []
      @api.keys.each { |key| users << user_for_key(key) }
      users.compact!
      projects.each do |project|
        users.each do |user|
          project.repository.readable_by(user)
        end
      end
    end
    
    class << self
      
      def run(options = {})
        options = GitAuth::Nash.new(options)
        options.user  = `git config --global github.user`.strip  unless options.user?
        options.token = `git config --global github.token`.strip unless options.token?
        logger.info "Preparing to run GitHub mirror for #{options.user}"
        mirror = self.new(options.user, options.token)
        logger.info "Mirroring all repositories"
        mirror.mirror_all
        logger.info "Mirroring user keys"
        mirror.mirror_user_keys
      rescue Exception => e
        logger.fatal "Got Exception: #{e.class.name} - #{e.message}"
        e.backtrace.each { |l| logger.fatal "--> #{l}" }
      end
      
      def version(include_path = false)
        VERSION[0, (include_path ? 4 : 3)].join(".")
      end
            
    end
    
    protected
    
    def github_url_for_repo(repo)
      p = repo.private?  
      "git#{p ? "@" : "://"}github.com#{p ? ":" : "/"}#{repo.owner}/#{repo.name}.git"
    end
    
    def mirrored?(repo)
      repo.repository.present?
    end
    
    def user_for_key(k)
      name = "gh-sync-#{Digest::SHA256.hexdigest(k.key)[0, 6]}"
      if u = GitAuth::User.get(name)
        u
      else
        if GitAuth::User.create(name, false, k.key)
          GitAuth::User.get(name)
        else
          raise "Unable to create user for key '#{k.key}'"
        end
      end
    end
    
  end
end

GitAuth::Loader.register_controller :mirror, GitAuth::GitHubMirror
