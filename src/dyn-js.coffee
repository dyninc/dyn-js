'use strict'

_     = require 'underscore'
q     = require 'q'
https = require 'https'
log   = require 'npmlog'
qs    = require 'querystring'

_.templateSettings = { interpolate: /\{\{(.+?)\}\}/g }

_request_q = (dyn, method, path, body, isTraffic) ->
  log.verbose 'dyn', "invoking via https : #{method} #{path}"
  defer = q.defer()

  cc = (a, b, c) ->
    log.verbose 'dyn', "invocation returned : #{method} #{path}"
    if (a != null)
      return defer.reject.call {}, [a]
    return defer.resolve.call {}, [a, b, c]

  host = dyn.defaults.host
  port = dyn.defaults.port
  path = dyn.defaults.prefix + path
  headers = _.clone dyn.defaults.headers

  if body && typeof(body) != 'string'
    body = JSON.stringify(body)
    headers['Content-Length'] = body.length
  else
    if body
      headers['Content-Length'] = body.length
    else
      headers['Content-Length'] = 0

  if isTraffic
    unless ((path.indexOf("/REST/Session/") == 0) && (method == 'POST'))
      if (dyn.defaults.token == null)
        throw new Error('must open a session first')
      headers['Auth-Token'] = dyn.defaults.token

  opts = {hostname:host,port:port,method:method,path:path,headers:headers}
  log.silly 'dyn', "request : #{JSON.stringify(opts)}"
  req = https.request opts, (res) ->
    # log.silly 'dynres', arguments
    data = ''
    res.on 'readable', ->
      # log.silly 'dynres', arguments
      chunk = res.read()
      # log.silly 'dyn', "partial : #{chunk}"
      data += chunk.toString('ascii')
    res.on 'end', ->
      log.silly 'dyn', "response : #{data}"
      response = JSON.parse(data)
      cc(null, response, res)
  req.on 'error', (e) ->
    log.warn 'dyn', "error : #{JSON.stringify(e)}"
    cc(e)
  req.write body if body
  req.end()

  return defer.promise

crudTraffic = (path, custom) ->
  custom ||= {}
  methods = {_list:'GET',_create:'POST',_get:'GET',_update:'PUT',_destroy:'DELETE'}
  _.reduce _.keys(methods), (a, x) ->
    a[x] ||= {}
    a[x]._path = (dyn, data) ->
      cpath = custom?[x]?.path || path
      _.template(cpath)(data)
    a[x]._call = (dyn, pathData, bodyData) ->
      log.silly 'dyn', "api call : #{x} -> #{path}"
      _request_q dyn, custom?.method || methods[x], a[x]._path(dyn, pathData), bodyData, true
    a
  , {}

crudMessaging = (path, custom) ->
  custom ||= {}
  methods = {_list:'GET',_create:'POST',_get:'GET',_update:'POST',_destroy:'POST'}
  allKeys = _.uniq _.keys(custom).concat(_.keys(methods))
  _.reduce allKeys, (a, x) ->
    a[x] ||= {}
    a[x]._path = (dyn, data) ->
      cpath = custom?[x]?.path || path
      data.e = escape
      _.template(cpath)(data)
    a[x]._call = (dyn, pathData, bodyData) ->
      log.silly 'dyn', "api call : #{x} -> #{path}"
      method = custom?[x]?.method || methods[x]
      if method == 'GET'
        _request_q dyn, method, a[x]._path(dyn, pathData) + "?" + qs.stringify(bodyData)
      else
        _request_q dyn, method, a[x]._path(dyn, pathData), qs.stringify(bodyData)
    a
  , {}

crudRecord = (type) ->
  crudTraffic "/#{type}Record/",
    _list:     {path:"/#{type}Record/{{zone}}/{{fqdn}}"}
    _create:   {path:"/#{type}Record/{{zone}}/{{fqdn}}/"}
    _get:      {path:"/#{type}Record/{{zone}}/{{fqdn}}/{{id}}"}
    _update:   {path:"/#{type}Record/{{zone}}/{{fqdn}}/{{id}}"}
    _destroy:  {path:"/#{type}Record/{{zone}}/{{fqdn}}/{{id}}"}

crudZone = ->
  crudTraffic "/Zone/",
    _list:     {path:"/Zone/"}
    _create:   {path:"/Zone/{{zone}}/"}
    _get:      {path:"/Zone/{{zone}}/"}
    _update:   {path:"/Zone/{{zone}}/"}
    _destroy:  {path:"/Zone/{{zone}}/"}

crudHttpRedirect = ->
  crudTraffic "/HTTPRedirect/",
    _get:      {path:"/HTTPRedirect/{{zone}}/{{fqdn}}"}
    _update:   {path:"/HTTPRedirect/{{zone}}/{{fqdn}}"}
    _create:   {path:"/HTTPRedirect/{{zone}}/{{fqdn}}"}
    _destroy:  {path:"/HTTPRedirect/{{zone}}/{{fqdn}}"}

crudGslb = ->
  crudTraffic "/GSLB/",
    _list:     {path:"/GSLB/{{zone}}"}
    _create:   {path:"/GSLB/{{zone}}/{{fqdn}}"}
    _get:      {path:"/GSLB/{{zone}}/{{fqdn}}"}
    _update:   {path:"/GSLB/{{zone}}/{{fqdn}}"}
    _destroy:  {path:"/GSLB/{{zone}}/{{fqdn}}"}

crudGslbRegion = ->
  crudTraffic "/GSLBRegion/",
    _list:     {path:"/GSLBRegion/{{zone}}"}
    _create:   {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _get:      {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _update:   {path:"/GSLBRegion/{{zone}}/{{fqdn}}/{{region_code}}"}
    _destroy:  {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}

crudSenders = (type) ->
  crudMessaging "/senders",
    _list:            {path:"/senders"}
    _create:          {path:"/senders"}
    _update:          {path:"/senders"}
    _details:         {path:"/senders/details", method:"GET"}
    _status:          {path:"/senders/status",  method:"GET"}
    _dkim:            {path:"/senders/dkim",    method:"POST"}
    _destroy:         {path:"/senders/delete"}

crudAccounts = (type) ->
  crudMessaging "/accounts",
    _list:            {path:"/accounts"}
    _create:          {path:"/accounts"}
    _destroy:         {path:"/accounts/delete"}
    _list_xheaders:   {path:"/accounts/xheaders", method:"GET"}
    _update_xheaders: {path:"/accounts/xheaders", method:"POST"}

crudRecipients = (type) ->
  crudMessaging "/recipients",
    _activate:        {path:"/recipients/activate", method:"POST"}
    _status:          {path:"/recipients/status", method: "GET"}

crudSendMail = (type) ->
  crudMessaging "/send/",
    _create:          {path:"/send"}

crudSuppressions = (type) ->
  crudMessaging "/suppressions",
    _list:            {path:"/suppressions"}
    _create:          {path:"/suppressions"}
    _activate:        {path:"/suppressions/activate", method: "POST"}
    _count:           {path:"/suppressions/count", method:"GET"}

crudReportsSentMail = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/sent"}
    _count:           {path:"/reports/sent/count", method:"GET"}

crudReportsDelivered = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/delivered"}
    _count:           {path:"/reports/delivered/count", method:"GET"}

crudReportsBounces = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/bounces"}
    _count:           {path:"/reports/bounces/count", method:"GET"}

crudReportsComplaints = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/complaints"}
    _count:           {path:"/reports/complaints/count", method:"GET"}

crudReportsIssues = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/issues"}
    _count:           {path:"/reports/issues/count", method:"GET"}

crudReportsOpens = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/opens"}
    _count:           {path:"/reports/opens/count", method:"GET"}
    _unique:          {path:"/reports/opens/unique", method:"GET"}
    _unique_count:    {path:"/reports/opens/count/unique", method:"GET"}

crudReportsClicks = (type) ->
  crudMessaging "/reports",
    _list:            {path:"/reports/clicks"}
    _count:           {path:"/reports/clicks/count", method:"GET"}
    _unique:          {path:"/reports/clicks/unique", method:"GET"}
    _unique_count:    {path:"/reports/clicks/count/unique", method:"GET"}

makePromise = (val) ->
  r = q.defer()
  r.resolve(val)
  r.promise

callWithError = (funProm, description, successFilter, successCase, errorCase) ->
  funProm.then (x) ->
    makePromise if successFilter(x[1])
      log.silly 'dyn', "api call returned successfully : #{JSON.stringify(x[1])}"
      successCase(x[1])
    else

      log.info 'dyn', "api call returned error : #{JSON.stringify(x[1])}"
      errorCase x[1]

  , (x) ->
    log.warn 'dyn', "unexpected error : #{JSON.stringify(x[1])}"
    errorCase x

isOk        = (x) -> x && (x.status == 'success')
identity    = (x) -> x
extract     = (key) -> (x) -> x?[key]
extractData = extract 'data'
extractMsgs = extract 'msgs'

msgIsOk        = (x) -> x && x.response && (x.response.status == 200)
extractMsgData = (x) -> x?.response?.data

okBool      = -> true
failBool    = -> false

extractRecords = (x) ->
  return [] unless x && x.data
  _(x.data).map (r) ->
    v = r.split("/")
    {type:v[2].replace(/Record$/, ""),zone:v[3],fqdn:v[4],id:v[5]}

extractZones = (x) ->
  return [] unless x && x.data
  _(x.data).map (r) ->
    v = r.split("/")
    {zone:v[3]}

throwMessages    = (x) -> throw (x.msgs || "unknown exception when calling api")
throwMsgMessages = (x) -> throw (x?.response?.message || "unknown exception when calling api")
throwResponse =(x) -> return x?.response || "unknown exception when calling api"

Dyn = (opts) ->
  traffic_defaults = _.defaults opts?.traffic || {}, {
    host: 'api2.dynect.net'
    port: 443
    prefix:'/REST'
    headers:{
      'Content-Type':'application/json'
      'User-Agent':'dyn-js v1.0.3'
    }
    token:null
  }

  messaging_defaults = _.defaults opts?.messaging || {}, {
    host: 'emailapi.dynect.net'
    port: 443
    prefix:'/rest/json'
    headers:{
      'Content-Type':'application/x-www-form-urlencoded'
      'User-Agent':'dyn-js v1.0.3'
    }
    apikey:null
  }

  dyn = {}
  dyn.traffic = {}

  traffic = dyn.traffic

  dyn.log = log
  dyn.log.level = "info"

  traffic.defaults = _.clone traffic_defaults

  traffic.withZone = (zone) ->
    traffic.defaults.zone = zone
    traffic

  traffic.zone         = crudZone()
  traffic.zone.list    = ()     -> callWithError traffic.zone._list._call(traffic, {}, {}), "zone.list", isOk, extractZones, throwMessages
  traffic.zone.create  = (args) -> callWithError traffic.zone._create._call(traffic, {zone:traffic.defaults.zone}, args), "zone.create", isOk, extractData, throwMessages
  traffic.zone.get     =        -> callWithError traffic.zone._list._call(traffic, {zone:traffic.defaults.zone}, {}), "zone.get", isOk, extractData, throwMessages
  traffic.zone.destroy =        -> callWithError traffic.zone._destroy._call(traffic, {zone:traffic.defaults.zone}, {}), "zone.destroy", isOk, extractMsgs, throwMessages
  traffic.zone.publish =        -> callWithError traffic.zone._update._call(traffic, {zone:traffic.defaults.zone}, {publish:true}), "zone.publish", isOk, extractData, throwMessages
  traffic.zone.freeze  =        -> callWithError traffic.zone._update._call(traffic, {zone:traffic.defaults.zone}, {freeze:true}), "zone.freeze", isOk, extractData, throwMessages
  traffic.zone.thaw    =        -> callWithError traffic.zone._update._call(traffic, {zone:traffic.defaults.zone}, {thaw:true}), "zone.thaw", isOk, extractData, throwMessages

  traffic.session  = crudTraffic "/Session/"
  traffic.session.create = -> callWithError(traffic.session._create._call(traffic, {}, _.pick(traffic.defaults, 'customer_name', 'user_name', 'password')), "session.create", isOk, (x) ->
    traffic.defaults.token = x.data.token
    makePromise x
  , throwMessages)
  traffic.session.destroy = -> callWithError(traffic.session._destroy._call(traffic, {}, {}), "session.destroy", isOk, (x) ->
    traffic.defaults.token = null
    makePromise x
  , throwMessages)

  recordTypes = ['All','ANY','A','AAAA','CERT','CNAME','DHCID','DNAME','DNSKEY','DS','IPSECKEY','KEY','KX','LOC','MX','NAPTR','NS','NSAP','PTR','PX','RP','SOA','SPF','SRV','SSHFP','TXT']
  whiteList   = {'All':'list','ANY':'list','SOA':{'list':true,'get':true,'update':true}}
  allow       = (x, op) -> !whiteList[x] || ( _.isString(whiteList[x]) && whiteList[x] == op) || ( _.isObject(whiteList[x]) && whiteList[x][op] )

  traffic.record = _.reduce recordTypes, (a, x) ->
    type = "_#{x}"
    a[type] = crudRecord(x)

    a[type].list    = ( (fqdn)             -> callWithError traffic.record[type]._list._call(traffic,    {zone:traffic.defaults.zone,fqdn:fqdn||''}, {}), "record._#{type}.list", isOk, extractRecords, throwMessages ) if allow(x, 'list')
    a[type].create  = ( (fqdn, record)     -> callWithError traffic.record[type]._create._call(traffic,  {zone:traffic.defaults.zone,fqdn:fqdn}, record), "record._#{type}.create", isOk, extractData, throwMessages )  if allow(x, 'create')
    a[type].destroy = ( (fqdn, opt_id)     -> callWithError traffic.record[type]._destroy._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn,id:opt_id||''}, {}), "record._#{type}.destroy", isOk, extractMsgs, throwMessages ) if allow(x, 'destroy')
    a[type].get     = ( (fqdn, id)         -> callWithError traffic.record[type]._get._call(traffic,     {zone:traffic.defaults.zone,fqdn:fqdn,id:id}, {}), "record._#{type}.get", isOk, extractRecords, throwMessages ) if allow(x, 'get')
    a[type].update  = ( (fqdn, id, record) -> callWithError traffic.record[type]._update._call(traffic,  {zone:traffic.defaults.zone,fqdn:fqdn,id:id}, record), "record._#{type}.update", isOk, extractData, throwMessages ) if allow(x, 'update')
    a[type].replace = ( (fqdn, records)    ->
      arg = {}
      arg["#{x}Records"] = records
      callWithError traffic.record[type]._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn,id:''}, arg), "record._#{type}.replace", isOk, extractData, throwMessages ) if allow(x, 'replace')
    a
  , {}

  traffic.http_redirect   = crudHttpRedirect()
  traffic.http_redirect.list    = (fqdn) -> callWithError traffic.http_redirect._list._call(traffic, {zone:traffic.defaults.zone}, {}), "http_redirect.list", isOk, extractData, throwMessages
  traffic.http_redirect.get     = (fqdn, detail) -> callWithError traffic.http_redirect._get._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {detail:detail||'N'}), "http_redirect.get", isOk, extractData, throwMessages
  traffic.http_redirect.create  = (fqdn, code, keep_uri, url) -> callWithError traffic.http_redirect._create._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {code:code, keep_uri:keep_uri, url:url}), "http_redirect.create", isOk, extractData, throwMessages
  traffic.http_redirect.update  = (fqdn, code, keep_uri, url) -> callWithError traffic.http_redirect._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {code:code, keep_uri:keep_uri, url:url}), "http_redirect.update", isOk, extractData, throwMessages
  traffic.http_redirect.destroy = (fqdn) -> callWithError traffic.http_redirect._destroy._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {}), "http_redirect.destroy", isOk, extractData, throwMessages

  traffic.gslb            = crudGslb()
  traffic.gslb.list       = (detail)     -> callWithError traffic.gslb._list._call(traffic, {zone:traffic.defaults.zone}, {detail:detail||'N'}), "gslb.list", isOk, extractData, throwMessages
  traffic.gslb.get        = (fqdn)       -> callWithError traffic.gslb._get._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {}), "gslb.get", isOk, extractData, throwMessages
  traffic.gslb.create     = (fqdn, opts) -> callWithError traffic.gslb._create._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, opts), "gslb.create", isOk, extractData, throwMessages
  traffic.gslb.destroy    = (fqdn)       -> callWithError traffic.gslb._destroy._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {}), "gslb.destroy", isOk, extractData, throwMessages
  traffic.gslb.update     = (fqdn, opts) -> callWithError traffic.gslb._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, opts), "gslb.update", isOk, extractData, throwMessages
  traffic.gslb.activate   = (fqdn)       -> callWithError traffic.gslb._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {activate:true}), "gslb.activate", isOk, extractData, throwMessages
  traffic.gslb.deactivate = (fqdn)       -> callWithError traffic.gslb._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {deactivate:true}), "gslb.deactivate", isOk, extractData, throwMessages
  traffic.gslb.recover    = (fqdn)       -> callWithError traffic.gslb._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {recover:true}), "gslb.recover", isOk, extractData, throwMessages
  traffic.gslb.recoverip  = (fqdn, opts) -> callWithError traffic.gslb._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, opts), "gslb.recoverip", isOk, extractData, throwMessages

  traffic.gslbRegion         = crudGslbRegion()
  traffic.gslbRegion.list    = (detail) -> callWithError traffic.gslbRegion._list._call(traffic, {zone:traffic.defaults.zone}, {detail:detail||'N'}), "gslbRegion.list", isOk, extractData, throwMessages
  traffic.gslbRegion.get     = (fqdn) -> callWithError traffic.gslbRegion._get._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {}), "gslbRegion.get", isOk, extractData, throwMessages
  traffic.gslbRegion.create  = (fqdn, opts) -> callWithError traffic.gslbRegion._create._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, opts), "gslbRegion.create", isOk, extractData, throwMessages
  traffic.gslbRegion.destroy = (fqdn) -> callWithError traffic.gslbRegion._destroy._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn}, {}), "gslbRegion.destroy", isOk, extractData, throwMessages
  traffic.gslbRegion.update  = (fqdn, region_code, opts) -> callWithError traffic.gslbRegion._update._call(traffic, {zone:traffic.defaults.zone,fqdn:fqdn,region_code:region_code}, opts), "gslbRegion.update", isOk, extractData, throwMessages

  dyn.messaging = {}
  messaging = dyn.messaging

  messaging.defaults = _.clone messaging_defaults

  messaging.senders                   = crudSenders()
  messaging.senders.list              = (startindex)     -> callWithError messaging.senders._list._call(messaging, {}, _.defaults({startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "senders.list", msgIsOk, extractMsgData, throwMsgMessages
  messaging.senders.create            = (email, seeding) -> callWithError messaging.senders._create._call(messaging, {}, _.defaults({emailaddress:email,seeding:seeding||'0'}, {apikey:messaging.defaults.apikey})), "senders.create", msgIsOk, extractMsgData, throwMsgMessages
  messaging.senders.update            = (email, seeding) -> callWithError messaging.senders._update._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "senders.update", msgIsOk, extractMsgData, throwMsgMessages
  messaging.senders.details           = (email)          -> callWithError messaging.senders._details._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "senders.details", msgIsOk, extractMsgData, throwMsgMessages
  messaging.senders.status            = (email)          -> callWithError messaging.senders._status._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "senders.status", msgIsOk, extractMsgData, throwResponse
  messaging.senders.dkim              = (email, dkim)    -> callWithError messaging.senders._dkim._call(messaging, {}, _.defaults({emailaddress:email,dkim:dkim}, {apikey:messaging.defaults.apikey})), "senders.dkim", msgIsOk, extractMsgData, throwMsgMessages
  messaging.senders.destroy           = (email)          -> callWithError messaging.senders._destroy._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "senders.destroy", msgIsOk, extractMsgData, throwMsgMessages

  messaging.accounts                  = crudAccounts()
  messaging.accounts.create           = (username, password, companyname, phone, address, city, state, zipcode, country, timezone, bounceurl, spamurl, unsubscribeurl, trackopens, tracelinks, trackunsubscribes, generatenewapikey) -> callWithError messaging.accounts._create._call(messaging, {}, _.defaults({username:username, password:password, companyname:companyname, phone:phone, address:address, city:city, state:state, zipcode:zipcode, country:country, timezone:timezone, bounceurl:bounceurl, spamurl:spamurl, unsubscribeurl:unsubscribeurl, trackopens:trackopens, tracelinks:tracelinks, trackunsubscribes:trackunsubscribes, generatenewapikey:generatenewapikey}, {apikey:messaging.defaults.apikey})), "accounts.create", msgIsOk, extractMsgData, throwMsgMessages
  messaging.accounts.list             = (startindex)      -> callWithError messaging.accounts._list._call(messaging, {}, _.defaults({startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "accounts.list", msgIsOk, extractMsgData, throwMsgMessages
  messaging.accounts.destroy          = (username)        -> callWithError messaging.accounts._destroy._call(messaging, {}, _.defaults({username:username}, {apikey:messaging.defaults.apikey})), "accounts.destroy", msgIsOk, extractMsgData, throwMsgMessages
  messaging.accounts.list_xheaders    =                   -> callWithError messaging.accounts._list_xheaders._call(messaging, {}, _.defaults({}, {apikey:messaging.defaults.apikey})), "accounts.list_xheaders", msgIsOk, extractMsgData, throwMsgMessages
  messaging.accounts.update_xheaders  = (xh1,xh2,xh3,xh4) -> callWithError messaging.accounts._update_xheaders._call(messaging, {}, _.defaults({xheader1:xh1,xheader2:xh2,xheader3:xh3,xheader4:xh4}, {apikey:messaging.defaults.apikey})), "accounts.update_xheaders", msgIsOk, extractMsgData, throwMsgMessages

  messaging.recipients                = crudRecipients()
  messaging.recipients.status         = (email) -> callWithError messaging.recipients._status._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "recipients.status", msgIsOk, extractMsgData, throwMsgMessages
  messaging.recipients.activate       = (email) -> callWithError messaging.recipients._activate._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "recipients.activate", msgIsOk, extractMsgData, throwMsgMessages

  messaging.suppressions              = crudSuppressions()
  messaging.suppressions.count        = (startdate, enddate)             -> callWithError messaging.suppressions._count._call(messaging, {}, _.defaults({}, {apikey:messaging.defaults.apikey})), "suppressions.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.suppressions.list         = (startdate, enddate, startindex) -> callWithError messaging.suppressions._list._call(messaging, {}, _.defaults({startdate:startdate, enddate:enddate, startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "suppressions.list", msgIsOk, extractMsgData, throwMsgMessages
  messaging.suppressions.create       = (email)                          -> callWithError messaging.suppressions._create._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "suppressions.create", msgIsOk, extractMsgData, throwMsgMessages
  messaging.suppressions.activate     = (email)                          -> callWithError messaging.suppressions._activate._call(messaging, {}, _.defaults({emailaddress:email}, {apikey:messaging.defaults.apikey})), "suppressions.activate", msgIsOk, extractMsgData, throwMsgMessages

  messaging.delivery                  = crudReportsDelivered()
  messaging.delivery.count           = (starttime, endtime)             -> callWithError messaging.delivery._count._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "delivery.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.delivery.list            = (starttime, endtime, startindex) -> callWithError messaging.delivery._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime, startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "delivery.list", msgIsOk, extractMsgData, throwMsgMessages

  messaging.sent_mail                 = crudReportsSentMail()
  messaging.sent_mail.count           = (starttime, endtime)             -> callWithError messaging.sent_mail._count._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "sent_mail.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.sent_mail.list            = (starttime, endtime, startindex) -> callWithError messaging.sent_mail._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime, startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "sent_mail.list", msgIsOk, extractMsgData, throwMsgMessages

  messaging.bounces                   = crudReportsBounces()
  messaging.bounces.count             = (starttime, endtime)             -> callWithError messaging.bounces._count._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "bounces.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.bounces.list              = (starttime, endtime, startindex) -> callWithError messaging.bounces._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime, startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "bounces.list", msgIsOk, extractMsgData, throwMsgMessages

  messaging.complaints                = crudReportsComplaints()
  messaging.complaints.count          = (starttime, endtime)             -> callWithError messaging.complaints._count._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "complaints.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.complaints.list           = (starttime, endtime, startindex) -> callWithError messaging.complaints._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime, startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "complaints.list", msgIsOk, extractMsgData, throwMsgMessages

  messaging.issues                    = crudReportsIssues()
  messaging.issues.count              = (starttime, endtime)             -> callWithError messaging.issues._count._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "issues.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.issues.list               = (starttime, endtime, startindex) -> callWithError messaging.issues._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime, startindex:startindex||'0'}, {apikey:messaging.defaults.apikey})), "issues.list", msgIsOk, extractMsgData, throwMsgMessages

  messaging.opens                     = crudReportsOpens()
  messaging.opens.count               = (starttime, endtime)             -> callWithError messaging.opens._count._call(messaging, {}, _.defaults({starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "opens.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.opens.list                = (starttime, endtime, startindex) -> callWithError messaging.opens._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "opens.list", msgIsOk, extractMsgData, throwMsgMessages
  messaging.opens.unique              = (starttime, endtime, startindex) -> callWithError messaging.opens._unique._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "opens.unqiue", msgIsOk, extractMsgData, throwMsgMessages
  messaging.opens.unique_count        = (starttime, endtime)             -> callWithError messaging.opens._unique_count._call(messaging, {}, _.defaults({starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "opens.unique_count", msgIsOk, extractMsgData, throwMsgMessages

  messaging.clicks                    = crudReportsClicks()
  messaging.clicks.count              = (starttime, endtime)             -> callWithError messaging.clicks._count._call(messaging, {}, _.defaults({starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "clicks.count", msgIsOk, extractMsgData, throwMsgMessages
  messaging.clicks.list               = (starttime, endtime, startindex) -> callWithError messaging.clicks._list._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "clicks.list", msgIsOk, extractMsgData, throwMsgMessages
  messaging.clicks.unique             = (starttime, endtime, startindex) -> callWithError messaging.clicks._unique._call(messaging, {}, _.defaults({starttime:starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "clicks.unique", msgIsOk, extractMsgData, throwMsgMessages
  messaging.clicks.unique_count       = (starttime, endtime)             -> callWithError messaging.clicks._unique_count._call(messaging, {}, _.defaults({starttime, endtime:endtime}, {apikey:messaging.defaults.apikey})), "clicks.unique_count", msgIsOk, extractMsgData, throwMsgMessages

  messaging.send_mail                 = crudSendMail()
  messaging.send_mail.create          = (from, to, subject, bodytext, bodyhmtl, cc, replyto, xheaders) -> callWithError messaging.send_mail._create._call(messaging, {}, _.defaults({from:from, to:to, subject:subject, bodytext:bodytext, bodyhtml:bodyhmtl, cc:cc, replyto:replyto, xheaders:xheaders}, {apikey:messaging.defaults.apikey})), "send_mail.create", msgIsOk, extractMsgData, throwMsgMessages

  dyn

module.exports = Dyn
