# frozen_string_literal: true

Lita.configure do |config|
  robot_name = ENV['ROBOT_NAME']
  config.robot.name = robot_name
  config.robot.mention_name = ENV['ROBOT_MENTION_NAME'] || robot_name

  log_level = ENV['ROBOT_LOG_LEVEL']
  config.robot.log_level = log_level ? log_level.to_sym : :info

  config.robot.adapter = :slack
  config.robot.admins = []

  config.adapters.slack.token = ENV['ADAPTERS_SLACK_TOKEN']

  if (vcap_services = ENV['VCAP_SERVICES'])
    rediscloud_service = JSON.parse(vcap_services)['rediscloud']
    credentials = rediscloud_service.first['credentials']
    config.redis[:host] = credentials['hostname']
    config.redis[:port] = credentials['port']
    config.redis[:password] = credentials['password']
  else
    config.redis[:host] = ENV['REDIS_HOST']
    config.redis[:port] = ENV['REDIS_PORT'].to_i
  end
end
