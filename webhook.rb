#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/logger'
require 'json'

class DeployWebhook < Sinatra::Base
  logger filename: "log/#{settings.environment}.log"
  
  configure do
    set :refs, ['refs/heads/develop']
    set :deploy_dir, '/home/deploy/avalon'
    set :logfile, '/home/deploy/avalon_deploy.log'
  end
  
  helpers do
    def deploy(branch)
      logger.info "Deploying #{branch} from #{settings.deploy_dir}"
      Dir.chdir(settings.deploy_dir) do
        system "git fetch && git checkout #{branch} && git pull origin #{branch} >> #{settings.logfile} 2>&1"
      end
    end
  end
  
  get '/' do
    "OK"
  end
  
  post '/' do
    logger.info "Received event: `#{request.env['X-Github-Event']}`"
    if request.env['X-Github-Event'] == 'push'
      payload = JSON.parse(request.body)
      logger.info "Ref: #{payload['ref']}"
      if settings.refs.include?(payload['ref'])
        branch = payload['ref'].split('/',3)
        deploy(branch)
      end
    end
  end
end
