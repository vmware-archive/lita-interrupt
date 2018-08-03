Lita.configure do |config|
  # The name your robot will use.
  config.robot.name = ENV['ROBOT_NAME']
  config.robot.mention_name = ENV['ROBOT_MENTION_NAME']

  # The locale code for the language to use.
  # config.robot.locale = :en

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = ENV['ROBOT_LOG_LEVEL'].to_sym

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]

  # The adapter you want to connect with. Make sure you've added the
  # appropriate gem to the Gemfile.
  config.robot.adapter = ENV['ROBOT_ADAPTER'].to_sym
  config.robot.admins = []
  ENV['ROBOT_ADMINS'].split(',').each do |admin|
    config.robot.admins << admin
  end

  config.adapters.slack.token = ENV['ADAPTERS_SLACK_TOKEN']
  # config.http.host = "https://pivotal.slack.com"

  ## Example: Set options for the chosen adapter.
  # config.adapter.username = "oalbertini"
  # config.adapter.password = "secret"

  ## Example: Set options for the Redis connection.
  config.redis.host = ENV['REDIS_HOST']
  config.redis.port = ENV['REDIS_PORT'].to_i

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"
end
