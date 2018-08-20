# lita-interrupt

This is a plugin for [Lita](https://www.lita.io/) which can be used to [connect to slack](https://github.com/litaio/lita-slack). This handler can talk to Trello via the [trello api](https://developers.trello.com/docs/).

## Usage

This Lita handler can find your interrupt pair by talking to the Trello API. It requires a Trello API key from someone with access to a team Trello board. Simply add the interrupt engineers to a list containing a card titled 'Interrupt'. Also, team member cards should have the appropriate Trello 'Member' associated with it (initials will appear at the bottom-right corner of the card).

You have to configure at least one admin. That admin can then add teammates to the Lita authorization group "team". You have to find out your unique slack id and supply it to the lita configuration. Details on how to do this are below, along with instructions for configuring the bot via environment variables, using the provided `lita_config.rb`.

# set-up

You will have to get a [Trello developer API key](https://trello.com/app-key), and also [set up a bot instance on slack](https://my.slack.com/services/new/lita).

# cf deploy

To deploy to cloud foundry, you have to create and bind a `rediscloud` service to the app, and set a few environment variables:

```
cf set-env interrupt ROBOT_NAME 'robot name'
cf set-env interrupt ROBOT_ADMINS 'admin1_slack_id,admin2_slack_id'
cf set-env interrupt ADAPTERS_SLACK_TOKEN 'adapters_slack_token'
cf set-env interrupt TRELLO_DEVELOPER_PUBLIC_KEY 'trello_developer_public_key'
cf set-env interrupt TRELLO_MEMBER_TOKEN 'trello_member_token'
cf set-env interrupt TRELLO_BOARD_NAME 'trello_board_name'
```

Then just clone this repo and `cf push` the app.

# running locally

You can also run the bot locally, and against a local redis to get a faster feedback cycle. To do that, start up a redis server:

```
redis-server --port 1234
```

and set these environment variables:

```
ROBOT_NAME='robot name'
ROBOT_ADMINS='your-slack-id'
ADAPTERS_SLACK_TOKEN='xoxb-your-slack-token-goes-here'
REDIS_HOST='127.0.0.1'
REDIS_PORT='1234'
TRELLO_DEVELOPER_PUBLIC_KEY='trello-dev-public-key'
TRELLO_MEMBER_TOKEN='trello-member-token'
TRELLO_BOARD_NAME='your-team-trello-board-name'
export ROBOT_NAME ROBOT_ADMINS ADAPTERS_SLACK_TOKEN REDIS_HOST REDIS_PORT TRELLO_DEVELOPER_PUBLIC_KEY TRELLO_MEMBER_TOKEN TRELLO_BOARD_NAME
```

Keep in mind that the team roster and authorization group work (see below) will have to be redone when you `cf push` unless you can transfer the redis data to the cloud instance.

To run locally, remember to `bundle install` in the base directory for the main bot app as well as the `lita-interrupt` handler directory.

# finding your slack id

An easy way to get your unique slack id is to start up the bot and look yourself up with the `users find` bot command. Comment out the `lita-interrupt` line from the `Gemfile` in the parent directory of this repo. Then run `bundle exec lita -c simple_lita_config.rb`. Keep in mind you will still need the non-Trello environment variables set except for `ROBOT_ADMINS`.

 Issue this command to the bot: `users find MENTION_NAME` where `MENTION_NAME` is your slack handle without the `@` symbol. Also, say `help` to the bot for a list of commands.

# setting up the team roster

Once you have your unique slack id, start up the bot with that id in the `ROBOT_ADMINS` environment variable. Remember to put the `lita-interrupt` line back in the `Gemfile`. Then add yourself to the `team` authorization group by commanding the bot in a private channel: `auth add SLACK_ID team`.

Then you can find the slack ids for the rest of your team with `users find`. You can now add them to the `team` authorization group.

At this point, anyone on the team can command the bot to add/remove teammates. Adding them requires knowledge of their Trello username. For example, `add @myteammmate trello_user123` associates your teammate with `trello_user123`. They can also add themselves with `add me trello_user123`. Removing is even easier: `remove @myteammate`, or `remove me`.
