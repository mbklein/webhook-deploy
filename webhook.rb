#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/logger'
require 'json'

class DeployWebhook < Sinatra::Base
  logger filename: "log/#{settings.environment}.log"
  
  configure do
    set :refs, ['refs/heads/develop']
    set :deploy_dir, '/var/www/webhook-deploy/tmp/avalon'
    set :logfile, '/var/www/webhook-deploy/log/avalon_deploy.log'
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
    event = request.env['HTTP_X_GITHUB_EVENT'].to_s
    logger.info "Received event: `#{event}`"
    if request.env['HTTP_X_GITHUB_EVENT'] == 'push'
      request.body.rewind
      payload = JSON.parse(request.body.read)
      logger.info "Ref: #{payload['ref']}"
      if settings.refs.include?(payload['ref'])
        branch = payload['ref'].split('/',3).last
        deploy(branch)
      end
    end
    event
  end
end
