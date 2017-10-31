#
# metaflop - web interface
# © 2012 by alexis reigel
# www.metaflop.com
#
# licensed under gpl v3
#

# the file "user" only contains the following line
# set :user, "<username>"
# if your local username is the same as the ssh-user you might not need this
require 'bundler/capistrano'
require 'capistrano-rbenv'
require 'dotenv/deployment/capistrano'

require 'capistrano/ext/multistage'
set :stages, %w(production staging)
set :default_stage, 'staging'

set :default_run_options, pty: true # password prompt from git
set :ssh_options, forward_agent: true # use local ssh key

set :application, 'metaflop'
set :scm, :git
set :repository, 'git@github.com:metaflop/metaflop-www.git'
set :git_enable_submodules, 1
# allows deployment of custom branch:
# `cap staging deploy -s branch=my_branch`
set :branch, fetch(:branch, 'master')

set :deploy_to, '/home/app/app'
set :deploy_via, :remote_cache # don't clone repo each time

set :user, 'app'

set :use_sudo, false

set :rbenv_ruby_version, File.read('.ruby-version').strip
set :rbenv_install_dependencies, false

set :maintenance_template_path, File.join(File.dirname(__FILE__), '../public/maintenance.html')
set :maintenance_target_path, -> { "#{fetch(:shared_path)}/system/maintenance.html" }

# unicorn wrapper restart
namespace :deploy do
  task :restart, roles: :app, except: { no_release: true } do
    run "RACK_ENV=#{rails_env} $HOME/bin/unicorn_wrapper restart"
  end

  namespace :assets do
    desc 'Compile assets'
    task :precompile do
      run "(cd #{latest_release} && bundle exec rake assets:precompile RACK_ENV=#{rails_env})"
    end
  end

  # custom maintenance page
  namespace :web do
    task :disable do
      on_rollback { run "rm -f #{fetch(:maintenance_target_path).shellescape}" }
      put File.read(fetch(:maintenance_template_path)), fetch(:maintenance_target_path)
    end

    task :enable do
      run "rm -f #{fetch(:maintenance_target_path).shellescape}"
    end
  end
end

namespace :config do
  task :db do
    upload('config/db.yml', "#{latest_release}/config/db.yml")
  end
end

before 'deploy:restart', 'config:db'
after 'config:db', 'deploy:assets:precompile'
