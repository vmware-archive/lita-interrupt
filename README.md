# lita-interrupt

This is a plugin for the Ruby bot [Lita](https://www.lita.io/) which can be used to [connect to slack](https://github.com/litaio/lita-slack). It can talk to trello via the [trello api](https://developers.trello.com/docs/).

## Usage

This bot can find your interrupt pair by talking to the trello API. It requires a trello API key from someone with access to the team trello board. Simply add the interrupt engineers to a list containing a card titled 'Interrupt'.

Right now an environment variable is read in which links trello usernames and slack ids. To find out your slack id, talk to an instance of the lita bot and say `users find mention_name`.

TODO: keep hash of team member information stored in a database and allow users to register with the bot by talking to it.
