require 'gitauth'

dir = Pathname.new(__FILE__).dirname.dirname
$:.unshift(dir) unless $:.include?(dir)

require 'git_hub_api'

module GitAuth
  class GitHubMirror
    include GitAuth::Loggable
    
    Project = Struct.new(:name, :github_clone_url, :repository)
    
    def initialize(username, token)
      @api = GitHubApi.new(username, token)
    end
    
    def projects
      @projects ||= @api.repositories.map do |repository|
        local_repo = GitAuth::Repo.get(name)
        Project.new(repository.name, github_url_for_repo(repository), local_repo)
      end
    end
    
    def mirror!(p)
      mirrored?(p) ? update!(p) : clone!(p) 
    end
    
    def update!(p)
      return unless p.repository
      Dir.chdir(p.repository.real_path) do
        GitAuth.run "git pull origin master --force"
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
    
    class << self
      
      def run(options = {})
        options = Marvin::Nash.new(options)
        options.user  = `git config --global github.user`.strip  unless options.user?
        options.token = `git config --global github.token`.strip unless options.token?
        logger.info "Preparing to run GitHub mirror for #{options.user}"
        mirror = self.new(options.user, options.token)
        mirror.mirror!
      rescue Exception => e
        GitAuth::ExceptionTracker.log(e)
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
    
  end
end
