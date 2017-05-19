leaderboard
===========

A Slack bot that provides a team leaderboard for keeping scores that are specific per room.
Uses Hubot brain and Hubot redis to store data.

API
---
*   hubot register <team> for http://<snake-app>.heroku.com - Register a <team> and <snake-app> on the leaderboard
*  `hubot win for <team>` - Scores a win for <team> on the leaderboard
*  `hubot loss for <team>` - Scores a loss for <team> on the leaderboard
*  `hubot score for <team>` - Display the scores for the <team>
*  `hubot top <amount>` - Display the top <amount> leaders from the leaderboard, <amount> is optional and defaults to 10
*  `hubot bottom <amount>` - Display the top <amount> leaders from the leaderboard, <amount> is optional and defaults to 10

## Configuration

Some of the behavior of this plugin is configured in the environment:


### Running leaderboard Locally

You can test your hubot by running the following, however some plugins will not
behave as expected unless the [environment variables](#configuration) they rely
upon have been set.

You can start leaderboard locally by running:

    % bin/hubot

You'll see some start up output and a prompt:

    [Sat Feb 28 2015 12:38:27 GMT+0000 (GMT)] INFO Using default redis on localhost:6379
    leaderboard>

Then you can interact with leaderboard by typing `leaderboard help`.

    leaderboard> leaderboard help
    leaderboard animate me <query> - The same thing as `image me`, except adds [snip]
    leaderboard help - Displays all of the help commands that leaderboard knows about.
    ...


## Deployment
```
    % heroku create --stack cedar
    % git push heroku master
```
If your Heroku account has been verified you can run the following to enable
and add the Redis to Go addon to your app.
```
    % heroku addons:add redistogo:nano
```
If you run into any problems, checkout Heroku's [docs][heroku-node-docs].

More detailed documentation can be found on the [deploying hubot onto
Heroku][deploy-heroku] wiki page.


## Slack Variables

The Slack adapter requires some environment variables.

You'll need a Web API token to call any of the Slack API methods. For custom integrations, you'll get this
[from the token generator](https://api.slack.com/docs/oauth-test-tokens), and for apps it will come as the final part
of the [OAuth dance](https://api.slack.com/docs/oauth).

```
    % heroku config:add HUBOT_SLACK_TOKEN="..."
```

##  Persistence

This bot uses the `hubot-redis-brain` package, you will need to add the
Redis to Go addon on Heroku which requires a verified account (see above) or you
can create an account at [Redis to Go][redistogo] and manually
set the `REDISTOGO_URL` variable.

```
    % heroku config:add REDISTOGO_URL="..."
```

[redistogo]: https://redistogo.com/

## Restart the bot

You may want to get comfortable with `heroku logs` and `heroku restart` if
you're having issues.
