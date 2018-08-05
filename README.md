# lita-interrupt

This is a plugin for the Ruby bot [Lita](https://www.lita.io/) which can be used to [connect to slack](https://github.com/litaio/lita-slack). It can talk to trello via the [trello api](https://developers.trello.com/docs/).

## Usage

This bot can find your interrupt pair by talking to the trello API. It requires a trello API key from someone with access to the team trello board. Simply add the interrupt engineers to a list containing a card titled 'Interrupt'. Also, the card that represents a team member should have the trello 'Member' associated with it (initials will appear at the bottom-right of the card).

Right now an environment variable links trello usernames to slack ids. To find out your slack id, talk to an instance of the lita bot and say `users find mention_name`.

# cf deploy

To deploy to cloud foundry, you have to create and bind a `rediscloud` service to the app, and set a few environment variables:

```
cf set-env interrupt ROBOT_NAME 'robot name'
cf set-env interrupt ROBOT_MENTION_NAME 'robot mention name'
cf set-env interrupt ROBOT_LOG_LEVEL 'info'
cf set-env interrupt ROBOT_ADAPTER 'slack'
cf set-env interrupt ROBOT_ADMINS 'admin1_slack_id,admin2_slack_id'
cf set-env interrupt ADAPTERS_SLACK_TOKEN 'adapters_slack_token'
cf set-env interrupt TEAM_MEMBERS_HASH 'team_member1_trello_username:team_member1_trello_slack_id,team_member2_trello_username:team_member2_trello_slack_id'
cf set-env interrupt TRELLO_DEVELOPER_PUBLIC_KEY 'trello_developer_public_key'
cf set-env interrupt TRELLO_MEMBER_TOKEN 'trello_member_token'
cf set-env interrupt TRELLO_BOARD_NAME 'trello_board_name'
```

TODO: keep hash of team member information stored in a database and allow users to register with the bot by talking to it.
