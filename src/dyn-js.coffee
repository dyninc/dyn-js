'use strict'

_     = require 'underscore'
q     = require 'q'
https = require 'https'
log   = require('npmlog')

_.templateSettings = { interpolate: /\{\{(.+?)\}\}/g }

_request_q = (dyn, method, path, body) ->
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

  if body
    body = JSON.stringify(body)
    headers['Content-Length'] = body.length
  else
    headers['Content-Length'] = 0

  unless ((path.indexOf("/REST/Session/") == 0) && (method == 'POST'))
    if (dyn.defaults.token == null)
      throw new Error('must open a session first')
    headers['Auth-Token'] = dyn.defaults.token

  opts = {hostname:host,port:port,method:method,path:path,headers:headers}
  log.silly 'dyn', "request : #{JSON.stringify(opts)}"
  req = https.request opts, (res) ->
    data = ''
    res.on 'readable', () ->
      chunk = res.read()
      data += chunk.toString('ascii')
    res.on 'end', ->
      log.silly 'dyn', "response : #{data}"
      response = JSON.parse(data)
      cc(null, response, res)
  req.on 'error', (e) ->
    log.warn 'dyn', "error : #{JSON.stringify(e)}"
    cc(e)
  req.write body if body

  return defer.promise

crud = (path, custom) ->
  custom ||= {}
  methods = {_list:'GET',_create:'POST',_get:'GET',_update:'PUT',_destroy:'DELETE'}
  _.reduce _.keys(methods), (a, x) ->
    a[x] ||= {}
    a[x]._path = (dyn, data) ->
      cpath = custom?[x]?.path || path
      _.template(cpath)(data)
    a[x]._call = (dyn, pathData, bodyData) ->
      log.silly 'dyn', "api call : #{x} -> #{path}"
      _request_q dyn, methods[x], a[x]._path(dyn, pathData), bodyData
    a
  , {}


crudRecord = (type) ->
  crud "/#{type}Record/",
    _list:     {path:"/#{type}Record/{{zone}}/{{fqdn}}"}
    _create:   {path:"/#{type}Record/{{zone}}/{{fqdn}}/"}
    _get:      {path:"/#{type}Record/{{zone}}/{{fqdn}}/{{id}}"}
    _update:   {path:"/#{type}Record/{{zone}}/{{fqdn}}/{{id}}"}
    _destroy:  {path:"/#{type}Record/{{zone}}/{{fqdn}}/{{id}}"}

crudZone = ->
  crud "/Zone/",
    _list:     {path:"/Zone/"}
    _create:   {path:"/Zone/{{zone}}/"}
    _get:      {path:"/Zone/{{zone}}/"}
    _update:   {path:"/Zone/{{zone}}/"}
    _destroy:  {path:"/Zone/{{zone}}/"}

crudGslb = ->
  crud "/GSLB/",
    _list:     {path:"/GSLBRegion/{{zone}}"}
    _create:   {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _get:      {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _update:   {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _destroy:  {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}

crudGslbRegion = ->
  crud "/GSLBRegion/",
    _list:     {path:"/GSLBRegion/{{zone}}"}
    _create:   {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _get:      {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}
    _update:   {path:"/GSLBRegion/{{zone}}/{{fqdn}}/{{region_code}}"}
    _destroy:  {path:"/GSLBRegion/{{zone}}/{{fqdn}}"}

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

throwMessages = (x) -> throw (x.msgs || "unknown exception when calling api")

Dyn = (opts) ->
  defaults = _.defaults opts || {}, {
    host: 'api2.dynect.net'
    port: 443
    prefix:'/REST'
    headers:{
      'Content-Type':'application/json'
      'User-Agent':'dyn-js v0.0.1'
    }
    token:null
  }

  dyn = {}
  dyn.traffic = {}

  traffic = dyn.traffic

  dyn.log = log
  dyn.log.level = "info"

  traffic.defaults = _.clone defaults

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

  traffic.session  = crud "/Session/"
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

  dyn

module.exports = Dyn
