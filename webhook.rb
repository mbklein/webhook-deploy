#!/usr/bin/env ruby

require 'sinatra'
require 'json'

class DeployWebhook < Sinatra::Base
  configure do
    set :refs, ['refs/heads/develop']
    set :deploy_dir, '/home/deploy/avalon'
    set :logfile, '/home/deploy/avalon_deploy.log'
  end
  
  helpers do
    def deploy(deploy_dir, branch)
      Dir.chdir(deploy_dir) do
        system "git fetch && git checkout #{branch} && git pull origin #{branch} >> #{settings.logfile} 2>&1"
      end
    end
  end
  
  post '/' do
    if request['X-Github-Event'] == 'push'
      payload = JSON.parse(request.body)
      if settings.refs.include?(payload['ref'])
        branch = payload['ref'].split('/',3)
        deploy(settings.deploy_dir, branch)
      end
    end
  end
end
