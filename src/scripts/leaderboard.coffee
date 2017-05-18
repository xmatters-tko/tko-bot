# Description
#   A team leaderboard for keep score that are specific per room
#
# Dependencies:
#   "underscore": ">= 1.0.0"
#   "clark": "0.0.6"
#
# Configuration:
#
# Commands:
#   hubot register for <team> - Register a <team> on the leaderboard
#   hubot win for <team> - Scores a win for <team> on the leaderboard
#   hubot loss for <team> - Scores a loss for <team> on the leaderboard
#   hubot score for <team> - Display the scores for the <team>
#   hubot top <amount> - Display the top <amount> leaders from the leaderboard
#   hubot bottom <amount> - Remove a team from the leaderboard
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
      scores: {}

    if typeof @robot.brain.data == "object"
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @cache.scores = @robot.brain.data.scores
      @cache.scoreLog = @robot.brain.data.scoreLog

    @robot.brain.on 'loaded', =>
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @cache.scores = @robot.brain.data.scores
      @cache.scoreLog = @robot.brain.data.scoreLog

  getTeam: (team, room) ->
    unless typeof @cache.scores[room] == "object"
      @cache.scores[room] = {}

    @cache.scores[room][team] ||= 0
    team

  saveTeam: (team, room) ->
    @saveScoreLog(team, room)
    @robot.brain.data.scores[room] = @cache.scores[room]
    @robot.brain.data.scoreLog[room] = @cache.scoreLog[room]
    @robot.brain.emit('save', @robot.brain.data)

    @cache.scores[room][team]

  addTeam: (team, room) ->
    if typeof @cache.scores[room] == "object"
      if typeof @cache.scores[room][team] == "object"
        return false

    if @validate(team, room)
      team = @getTeam(team, room)
      score = @saveTeam(team, room)
      return true

    return false

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

  isSpam: (team, room) ->
    @cache.scoreLog[room] ||= {}

    if !@cache.scoreLog[room][team]
      return false

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

  roomRegistrations: (room) ->
    unless typeof @cache.scores[room] == "object"
      return 0
    _.size(@cache.scores[room])

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

  robot.respond /register (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    added = scoreKeeper.addTeam(name, room)

    if added then msg.send "Your team #{name} has been registered."

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

    if scoreKeeper.roomRegistrations(room) > 0
      tops = scoreKeeper[msg.match[1]](amount, room)

      for i in [0..tops.length-1]
        message.push("#{i+1}. #{tops[i].name} : #{tops[i].score}")

      if(msg.match[1] == "top")
        graphSize = Math.min(tops.length, Math.min(amount, 20))
        message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)))
    else
      message.push("No registrations yet.")

    msg.send message.join("\n")
