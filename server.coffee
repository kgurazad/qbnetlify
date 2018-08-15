express = require 'express'
request = require 'request'
mongoose = require 'mongoose'
app = express()
mongoose.connect process.env.DB

port = process.env.PORT || 2020

schema = mongoose.Schema({
    text: Object,
    difficulty: Number,
    tournament: Object,
    category: String,
    subcategory: String
})
model = mongoose.model('qs',schema,'raw-quizdb-clean')

split = (str, separator) ->  
  if str.length == 0
    return []
  str.split separator

mergeSpaces = (arr) ->
  res = ''
  for str in arr
    res += ' '
    res += str
  return res.slice 1

escapeRegExp = (str) ->
  str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, '\\$&'

app.get '/', (req, res) ->
  res.sendFile __dirname+'/index.html'
  return

app.get '/info', (req, res) ->
  res.sendFile __dirname+'/info.html'
  return

app.get '/favicon.ico', (req, res) ->
  res.sendFile __dirname+'/favicon.ico'
  return

app.get '/client.js', (req, res) ->
  res.sendFile __dirname+'/client.js'
  return
    
app.get '/style.css', (req, res) ->
  res.sendFile __dirname+'/style.css'
  return

app.get '/search/:search', (req, res) ->
  try
    search = req.params.search.split('!')
    console.log search
    queryString = escapeRegExp search[0]
    console.log queryString
    query = {}
    categories = split(search[1], ',')
    console.log categories
    subcategories = split(search[2], ',')
    console.log subcategories
    difficulties = split(search[3], ',')
    console.log difficulties
    tournamentsRaw = split(search[4], ',')
    console.log tournamentsRaw
    tournaments = {$or: []} # as it is in the mongodb
    searchType = search[5]
    console.log searchType

    searchParams = {$and: []}

    for k,v of difficulties
      difficulties[k] = Number v
    console.log difficulties

    if tournamentsRaw.length == 0
      tournaments = {'tournament': {$exists: true}}
    for tournament in tournamentsRaw
      tSplit = split tournament, ' '
      console.log tSplit
      try
        year = Number tSplit[0]
        if !year
          throw "nan"
        if tSplit.length == 1
          tournaments.$or.push {'tournament.year': year, 'tournament.name': {$exists: true} }
        else
          tournaments.$or.push {'tournament.year': year, 'tournament.name': mergeSpaces tSplit.slice 1 }
      catch e
        tournaments.$or.push {'tournament.year': {$exists: true}, 'tournament.name': mergeSpaces tSplit }

    if tournamentsRaw.length == 1
      tournaments = tournaments.$or[0]
    console.log tournaments

    if searchType == 'qa'
      query.$or = []
      query.$or.push {'text.question': {$regex: new RegExp(queryString, 'i')}}
      query.$or.push {'text.answer': {$regex: new RegExp(queryString, 'i')}}
    else if searchType == 'q'
      query = {'text.question': {$regex: new RegExp(queryString, 'i')}}
    else
      query = {'text.answer': {$regex: new RegExp(queryString, 'i')}}

    if queryString == ''
      query = {'text': {$exists: true}}
    console.log query

    searchParams.$and.push query
    searchParams.$and.push tournaments
    searchParams['difficulty'] = {$in: difficulties}
    searchParams['category'] = {$in: categories}
    searchParams['subcategory'] = {$in: subcategories}

    if difficulties.length == 0
      searchParams['difficulty'] = undefined
      
    if categories.length == 0
      searchParams['category'] = undefined
      
    if subcategories.length == 0
      searchParams['subcategory'] = undefined

    console.log JSON.stringify searchParams

    model.estimatedDocumentCount searchParams, (err, count) ->
      console.log 'there are ' + count  + ' documents found'
      if count > 1331
        console.log 'aggregating!'
        aggregateParams = [searchParams, {$sample: {size: 1331}]
        model.aggregate aggregateParams, (err, data) ->
          console.log 'there are ' + data.length + ' documents to be sent'
          if err?
            console.log err.stack
            res.sendStatus 503
            return
          res.send data
          return
	# comment
      else
        console.log 'regular finding!'
        model.find searchParams, (err, data) ->
          console.log 'there are ' + data.length + ' documents to be sent'
          if err?
            console.log err.stack
            res.sendStatus 503
            return
          res.send data
          return
        # comment
      return
	
  catch e
    console.log e.stack
    res.sendStatus 400
    
  return

app.listen port, () ->
  console.log 'listening on port ' + port + ' :)'
  return
