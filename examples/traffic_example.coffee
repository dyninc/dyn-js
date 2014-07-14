Dyn = require '../lib/dyn-js.js'
async = require 'async-q'
log = require 'npmlog'

dynClient = Dyn({traffic:{customer_name:'yourcustomer',user_name:'youruser',password:'yourpassword'}})
dynClient.log.level = 'sil'

dyn = dynClient.traffic.withZone('example.com')

fail = (bad) -> console.log 'FAIL', arguments

async.series([
  -> dyn.session.create()
  ->
    dyn.zone.list().then (x) ->
      log.info 'RESULT', "got zones: #{JSON.stringify(x)}"
      x
  -> dyn.zone.destroy().then (x) ->
      log.info 'RESULT', "zone removed: #{JSON.stringify(x)}"
      x
  -> dyn.zone.create({rname:'admin@example.com',ttl:60}).then (x) ->
      log.info 'RESULT', "created new zone: #{JSON.stringify(x)}"
      x
  -> dyn.record._A.create('local2.example.com',{rdata:{address:'127.0.0.1'}}).then (x) ->
      log.info 'RESULT', "created an A record: #{JSON.stringify(x)}"
      x
  -> dyn.record._CNAME.create('local.example.com', {rdata:{cname:'locale2.example.com'}}).then (x) ->
       log.info 'RESULT', "created a CNAME record: #{JSON.stringify(x)}"
       x
  -> dyn.http_redirect.create('overhere.example.com',302,"Y",'http://overthere.example.com').then (x) ->
      log.info 'RESULT', "created a redirect: #{JSON.stringify(x)}"
      x
  -> dyn.gslb.create('hello.example.com', {region:{region_code:'global', pool:{address:'hi.example.com'}}}).then (x) ->
     log.info 'RESULT', "created a gslb service: #{JSON.stringify(x)}"
     x
  -> dyn.session.destroy()
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail