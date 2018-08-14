Lita.configure do |config|
  config.robot.name = ENV['ROBOT_NAME']
  config.robot.mention_name = ENV['ROBOT_MENTION_NAME']

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = ENV['ROBOT_LOG_LEVEL'].to_sym

  config.robot.adapter = ENV['ROBOT_ADAPTER'].to_sym
  config.robot.admins = []
  ENV['ROBOT_ADMINS'].split(',').each do |admin|
    config.robot.admins << admin
  end

  config.adapters.slack.token = ENV['ADAPTERS_SLACK_TOKEN']

  if vcap_services = ENV['VCAP_SERVICES'] then
    rediscloud_service = JSON.parse(vcap_services)["rediscloud"]
    credentials = rediscloud_service.first["credentials"]
    config.redis[:host] = credentials["hostname"]
    config.redis[:port] = credentials["port"]
    config.redis[:password] = credentials["password"]
  else
    config.redis[:host] = ENV['REDIS_HOST']
    config.redis[:port] = ENV['REDIS_PORT'].to_i
  end

  config.handlers.interrupt.trello_developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
  config.handlers.interrupt.trello_member_token = ENV['TRELLO_MEMBER_TOKEN']
  config.handlers.interrupt.board_name = ENV['TRELLO_BOARD_NAME']
  config.handlers.interrupt.team_members_hash = ENV['TEAM_MEMBERS_HASH']
  config.handlers.interrupt.admins = config.robot.admins
end
