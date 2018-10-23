# frozen_string_literal: true

Lita.configure do |config|
  robot_name = ENV['ROBOT_NAME']
  config.robot.name = robot_name
  config.robot.mention_name = ENV['ROBOT_MENTION_NAME'] || robot_name

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  log_level = ENV['ROBOT_LOG_LEVEL']
  config.robot.log_level = log_level ? log_level.to_sym : :info

  config.robot.adapter = :slack
  config.robot.admins = []
  ENV['ROBOT_ADMINS']&.split(',')&.each { |admin| config.robot.admins << admin }

  config.adapters.slack.token = ENV['ADAPTERS_SLACK_TOKEN']

  config.handlers.interrupt.trello_developer_public_key = \
    ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
  config.handlers.interrupt.trello_member_token = ENV['TRELLO_MEMBER_TOKEN']
  config.handlers.interrupt.board_name = ENV['TRELLO_BOARD_NAME']

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
