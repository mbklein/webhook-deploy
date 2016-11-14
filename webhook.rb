#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/logger'
require 'json'

class DeployWebhook < Sinatra::Base
  logger filename: "log/#{settings.environment}.log"
  
  configure do
    set :refs, ENV['WEBHOOK_REFS'].split(/,\s*/)
    set :deploy_dir, ENV['WEBHOOK_SOURCE']
    set :logfile, ENV['WEBHOOK_LOG']
    set :stage, ENV['WEBHOOK_STAGE']
  end
  
  before do
    request.body.rewind
    @payload_body = request.body.read
  end
  
  helpers do
    def deploy(branch)
      logger.info "Deploying #{branch} from #{settings.deploy_dir}"
      env = { 
        'BUNDLE_GEMFILE' => File.join(settings.deploy_dir,'Gemfile'),
        'LOG' => settings.logfile, 
        'SCM_BRANCH' => branch, 
        'SOURCE' => settings.deploy_dir,
        'STAGE' => settings.stage
      }
      cmd = ['/bin/bash','-l','-c',File.expand_path('../bin/deploy',__FILE__)].join ' '
      logger.info "Running command: #{cmd}"
      child_pid = Process.spawn(env, cmd, unsetenv_others: false)
      logger.info "PID: #{child_pid}"
      Process.detach(child_pid)
    end
    
    def verify_signature!
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['WEBHOOK_SECRET'], @payload_body)
      return halt 403, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
    end
  end
  
  get '/' do
    "OK"
  end
  
  post '/' do
    verify_signature!
    event = request.env['HTTP_X_GITHUB_EVENT'].to_s
    logger.info "Received event: `#{event}`"
    if request.env['HTTP_X_GITHUB_EVENT'] == 'push'
      payload = JSON.parse(@payload_body)
      logger.info "Ref: #{payload['ref']}"
      if settings.refs.include?(payload['ref'])
        branch = payload['ref'].split('/',3).last
        deploy(branch)
      end
    end
    event
  end
end
