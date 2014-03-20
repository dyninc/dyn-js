
dynClient = Dyn({customer_name:'yourcustomer',user_name:'yourusername',password:'yourpassword'})
dynClient.log.level = 'info'

dyn = dynClient.traffic.withZone('example.com')

fail = (bad) -> console.log 'FAIL', arguments

async.series([
  -> dyn.session.create()
  ->
    dyn.zone.list().then (x) ->
      log.info 'RESULT', "got zones: #{JSON.stringify(x)}"
      x
  -> dyn.zone.destroy()
  -> dyn.zone.create({rname:'admin@example.com',ttl:60})
  -> dyn.record._All.list()
#  -> dyn.record._A.get('local.example.com')
#  -> dyn.record._A.destroy('local.example.com')
#  -> dyn.record._A.create('local.example.com',{rdata:{address:'127.0.0.1'}})
#  -> dyn.record._A.create('locals.example.com',{rdata:{address:'127.0.0.1'}})
#  -> dyn.record._A.replace('local.example.com',[{rdata:{address:'127.0.0.1'}},{rdata:{address:'127.0.0.9'}}])
#  -> dyn.record._A.update('locals.example.com', 100962004, {rdata:{address:'127.0.0.8'}})
#  -> dyn.zone.publish()
  -> dyn.session.destroy()
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail
