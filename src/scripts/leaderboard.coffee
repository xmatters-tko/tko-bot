# Description
#   A team leaderboard for keeping scores that are specific per room, with team urls
#
# Dependencies:
#   "underscore": ">= 1.0.0"
#   "clark": "0.0.6"
#
# Configuration:
#
# Commands:
#   hubot register <team> for http://<snake-app>.heroku.com - Register a <team> and <snake-app> on the leaderboard
#   hubot list - List all of the team registrations on the leaderboard
#   hubot win for <team> - Scores a win for <team> on the leaderboard
#   hubot loss for <team> - Scores a loss for <team> on the leaderboard
#   hubot score for <team> - Display the scores for the <team>
#   hubot top <amount> - Display the <amount> top teams from the leaderboard, <amount> is optional and defaults to 10
#   hubot bottom <amount> - Display the <amount> bottom teams from the leaderboard, <amount> is optional and defaults to 10
#
# Notes:
#
# Author:
#   xm-craig <cgulliver@xmatters.com>

_ = require('underscore')
clark = require('clark')
class ScoreKeeper
  constructor: (@robot) ->
    @cache =
      scoreLog: {}
      teamUrls: {}
      scores: {}

    if typeof @robot.brain.data == "object"
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @robot.brain.data.teamUrls ||= {}
      @cache.scores = @robot.brain.data.scores
      @cache.scoreLog = @robot.brain.data.scoreLog
      @cache.teamUrls = @robot.brain.data.teamUrls

    @robot.brain.on 'loaded', =>
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @robot.brain.data.teamUrls ||= {}
      @cache.scores = @robot.brain.data.scores
      @cache.scoreLog = @robot.brain.data.scoreLog
      @cache.teamUrls = @robot.brain.data.teamUrls

  getTeam: (team, room) ->
    unless typeof @cache.scores[room] == "object"
      @cache.scores[room] = {}
    unless typeof @cache.teamUrls[room] == "object"
      @cache.teamUrls[room] = {}

    @cache.scores[room][team] ||= 0
    @cache.teamUrls[room][team] ||= "EMPTY"
    team

  saveTeam: (team, room) ->
    @saveScoreLog(team, room)
    @robot.brain.data.scores[room] = @cache.scores[room]
    @robot.brain.data.scoreLog[room] = @cache.scoreLog[room]
    @robot.brain.data.teamUrls[room] = @cache.teamUrls[room]
    @robot.brain.emit('save', @robot.brain.data)

    @cache.scores[room][team]

  addTeam: (team, room, url) ->
    if @validate(team, room)
      team = @getTeam(team, room)
      @setTeamUrl(url, team, room)
      score = @saveTeam(team, room)

  win: (team, room) ->
    if @validate(team, room)
      team = @getTeam(team, room)
      @cache.scores[room][team]++
      @saveTeam(team, room)

  loss: (team, room) ->
    if @validate(team, room)
      team = @getTeam(team, room)
      @cache.scores[room][team]--
      @saveTeam(team, room)

  scoreForTeam: (team, room) -> 
    team = @getTeam(team, room)
    @cache.scores[room][team]

  saveScoreLog: (team, room) ->
    unless typeof @cache.scoreLog[room] == "object"
      @cache.scoreLog[room] = {}

    @cache.scoreLog[room][team] = new Date()

  setTeamUrl: (url, team, room) ->
    unless typeof @cache.teamUrls[room] == "object"
      @cache.teamUrls[room] = {}

    @cache.teamUrls[room][team] = url

  isSpam: (team, room) ->
    @cache.scoreLog[room] ||= {}

    // spam if they are not registered
    if !@cache.scoreLog[room][team]
      return true

    dateSubmitted = @cache.scoreLog[room][team]

    date = new Date(dateSubmitted)
    messageIsSpam = date.setSeconds(date.getSeconds() + 30) > new Date()

    if !messageIsSpam
      delete @cache.scoreLog[room][team] #clean it up

    messageIsSpam

  validate: (team, room) ->
    team != room && team != "" && !@isSpam(team, room)

  length: () ->
    @cache.scoreLog.length

  registrationCount: (room) ->
    unless typeof @cache.scores[room] == "object"
      return 0
    _.size(@cache.scores[room])

  registrations: (room) ->
    regs = []
    for name, score of @cache.scores[room]
      regs.push(name: name, score: score, url: @cache.teamUrls[room][name])
    _.sortBy( regs, 'name' )

  top: (amount, room) ->
    tops = []

    for name, score of @cache.scores[room]
      tops.push(name: name, score: score)

    tops.sort((a,b) -> b.score - a.score).slice(0,amount)

  bottom: (amount, room) ->
    all = @top(@cache.scores[room].length, room)
    all.sort((a,b) -> b.score - a.score).reverse().slice(0,amount)

module.exports = (robot) ->
  scoreKeeper = new ScoreKeeper(robot)
  reasonsKeyword = process.env.HUBOT_LEADERBOARD_REASONS or 'raisins'

  robot.respond /register (.+)?(\sfor\s)+(http\:\/\/.*\.heroku\.com)+/i, (msg) ->
    name = msg.match[1].trim().toLowerCase()
    room = msg.message.room || 'escape'
    url = msg.match[3].trim()

    scoreKeeper.addTeam(name, room, url)
    msg.send "Your team #{name} has been registered for #{url}."

  robot.respond /win (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    newScore = scoreKeeper.win(name, room)

    if newScore? then msg.send "Team #{name} has #{newScore} points."

  robot.respond /loss (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    newScore = scoreKeeper.loss(name, room)

    if newScore? then msg.send "Team #{name} has #{newScore} points."

  robot.respond /score (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    score = scoreKeeper.scoreForTeam(name, room)

    msg.send "Team #{name} has #{score} points."

  robot.respond /(top|bottom)(\s*)?(\d*)/i, (msg) ->
    amount = parseInt(msg.match[3]) || 10
    room = msg.message.room || 'escape'
    message = []

    if scoreKeeper.registrationCount(room) > 0
      tops = scoreKeeper[msg.match[1]](amount, room)

      for i in [0..tops.length-1]
        message.push("#{i+1}. #{tops[i].name} : #{tops[i].score} ")

      if(msg.match[1] == "top")
        graphSize = Math.min(tops.length, Math.min(amount, 20))
        message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)))
    else
      message.push("No registrations yet.")

    msg.send message.join("\n")


  robot.respond /list/i, (msg) ->
    room = msg.message.room || 'escape'
    message = []

    if scoreKeeper.registrationCount(room) > 0
      regs = scoreKeeper.registrations(room)
      for i in [0..regs.length-1]
        message.push("#{i+1}. #{regs[i].name} : #{regs[i].url} : #{regs[i].score}  ")
    else
      message.push("No registrations yet.")

    msg.send message.join("\n")
