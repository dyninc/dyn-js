
Dyn = require '../lib/dyn-js'
async = require 'async-q'
log = require 'npmlog'

dynClient = Dyn({messaging:{apikey:"yourapikey"}})
dynClient.log.level = 'silly'

dyn = dynClient.messaging

fail = (bad) -> console.log 'FAIL', arguments

# senders: list, create, update, details, status, dkim, destroy)
async.series([
  -> dyn.senders.create("foo@bars.com").then (x) ->
     log.info 'RESULT', "created sender: #{JSON.stringify(x)}"
     x
  -> dyn.senders.list().then (x) ->
     log.info 'RESULT', "got senders: #{JSON.stringify(x)}"
     x
  -> dyn.senders.update("foo@bars.com", 3).then (x) ->
     log.info 'RESULT', "updated sender: #{JSON.stringify(x)}"
     x
  -> dyn.senders.status("foo@bars.com").then (x) ->
     log.info 'RESULT', "got sender status: #{JSON.stringify(x)}"
     x
  -> dyn.senders.details("foo@bars.com").then (x) ->
     log.info 'RESULT', "got sender detail: #{JSON.stringify(x)}"
     x
  -> dyn.senders.destroy("foo@bars.com").then (x) ->
     log.info 'RESULT', "deleted sender: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# accounts: list, create, destroy, list xheaders, update xheaders
async.series([
  -> dyn.accounts.create("example@foo.com", "secret", "bar", "1234567890").then (x) ->
     log.info 'RESULT', "created account: #{JSON.stringify(x)}"
     x
  -> dyn.accounts.list().then (x) ->
     log.info 'RESULT', "got accounts: #{JSON.stringify(x)}"
     x
  -> dyn.accounts.list_xheaders().then (x) ->
     log.info 'RESULT', "got xheaders: #{JSON.stringify(x)}"
     x
  -> dyn.accounts.update_xheaders("X-Test1", "X-AnotherTest2", "X-Testing3", "X-FullyTested4").then (x) ->
     log.info 'RESULT', "updated xheaders: #{JSON.stringify(x)}"
     x
  -> dyn.accounts.destroy("example@foo.com").then (x) ->
     log.info 'RESULT', "deleted account: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# recipients: activate, status
async.series([
  -> dyn.recipients.activate("foo@bars.com").then (x) ->
     log.info 'RESULT', "activated recipient: #{JSON.stringify(x)}"
     x
  -> dyn.recipients.status("foo@bars.com").then (x) ->
     log.info 'RESULT', "got status of recipient: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

send mail: create
async.series([
  -> dyn.send_mail.create("foo@bars.com", "recipient@destination.com", "hello, new js api", "it works!").then (x) ->
     log.info 'RESULT', "sent mail: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# suppressions: list, create, activate, count
async.series([
  -> dyn.suppressions.create("foos@bars.com").then (x) ->
     log.info 'RESULT', "suppressed: #{JSON.stringify(x)}"
     x
  -> dyn.suppressions.list().then (x) ->
     log.info 'RESULT', "got suppressions: #{JSON.stringify(x)}"
     x
  -> dyn.suppressions.activate("foos@bars.com").then (x) ->
     log.info 'RESULT', "activated suppression: #{JSON.stringify(x)}"
     x
  -> dyn.suppressions.activate("foos@bars.com").then (x) ->
     log.info 'RESULT', "activated suppression: #{JSON.stringify(x)}"
     x
  -> dyn.suppressions.count().then (x) ->
     log.info 'RESULT', "suppression count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# sent: list, count
async.series([
  -> dyn.sent_mail.list().then (x) ->
     log.info 'RESULT', "got sent list: #{JSON.stringify(x)}"
     x
  -> dyn.sent_mail.count().then (x) ->
     log.info 'RESULT', "got sent count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# delivery: list, count
async.series([
  -> dyn.delivery.list().then (x) ->
     log.info 'RESULT', "got delivery list: #{JSON.stringify(x)}"
     x
  -> dyn.delivery.count().then (x) ->
     log.info 'RESULT', "got delivery count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# bounces: list, count
async.series([
  -> dyn.bounces.list('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got bounces list: #{JSON.stringify(x)}"
     x
  -> dyn.bounces.count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got bounces count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# complaints: list, count
async.series([
  -> dyn.complaints.list('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got complaints list: #{JSON.stringify(x)}"
     x
  -> dyn.complaints.count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got complaints count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# issues: list, count
async.series([
  -> dyn.issues.list('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got issues list: #{JSON.stringify(x)}"
     x
  -> dyn.issues.count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got issues count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# opens: list, count, unique, unique count
async.series([
  -> dyn.opens.list('2013-11-19', '2014-06-18').then (x) ->
      log.info 'RESULT', "got opens list: #{JSON.stringify(x)}"
      x
  -> dyn.opens.count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got opens count: #{JSON.stringify(x)}"
     x
  -> dyn.opens.unique('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got unique opens list: #{JSON.stringify(x)}"
     x
  -> dyn.opens.unique_count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got unique opens count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

# clicks: list, count, unique, unique count
async.series([
  -> dyn.clicks.list('2013-11-19', '2014-06-18').then (x) ->
      log.info 'RESULT', "got clicks list: #{JSON.stringify(x)}"
      x
  -> dyn.clicks.count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got clicks count: #{JSON.stringify(x)}"
     x
  -> dyn.clicks.unique('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got unique clicks list: #{JSON.stringify(x)}"
     x
  -> dyn.clicks.unique_count('2013-11-19', '2014-06-18').then (x) ->
     log.info 'RESULT', "got unique clicks count: #{JSON.stringify(x)}"
     x
]).then ->
  _(arguments[0]).forEach (x) ->
    log.info 'RESULT', "finished : #{JSON.stringify(x)}"
, fail

