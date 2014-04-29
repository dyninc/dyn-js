'use strict';
var Dyn, callWithError, crud, crudGslb, crudGslbRegion, crudRecord, crudZone, extract, extractData, extractMsgs, extractRecords, extractZones, failBool, https, identity, isOk, log, makePromise, okBool, q, throwMessages, _, _request_q;

_ = require('underscore');

q = require('q');

https = require('https');

log = require('npmlog');

_.templateSettings = {
  interpolate: /\{\{(.+?)\}\}/g
};

_request_q = function(dyn, method, path, body) {
  var cc, defer, headers, host, opts, port, req;
  log.verbose('dyn', "invoking via https : " + method + " " + path);
  defer = q.defer();
  cc = function(a, b, c) {
    log.verbose('dyn', "invocation returned : " + method + " " + path);
    if (a !== null) {
      return defer.reject.call({}, [a]);
    }
    return defer.resolve.call({}, [a, b, c]);
  };
  host = dyn.defaults.host;
  port = dyn.defaults.port;
  path = dyn.defaults.prefix + path;
  headers = _.clone(dyn.defaults.headers);
  if (body) {
    body = JSON.stringify(body);
    headers['Content-Length'] = body.length;
  } else {
    headers['Content-Length'] = 0;
  }
  if (!((path.indexOf("/REST/Session/") === 0) && (method === 'POST'))) {
    if (dyn.defaults.token === null) {
      throw new Error('must open a session first');
    }
    headers['Auth-Token'] = dyn.defaults.token;
  }
  opts = {
    hostname: host,
    port: port,
    method: method,
    path: path,
    headers: headers
  };
  log.silly('dyn', "request : " + (JSON.stringify(opts)));
  req = https.request(opts, function(res) {
    var data;
    data = '';
    res.on('readable', function() {
      var chunk;
      chunk = res.read();
      return data += chunk.toString('ascii');
    });
    return res.on('end', function() {
      var response;
      log.silly('dyn', "response : " + data);
      response = JSON.parse(data);
      return cc(null, response, res);
    });
  });
  req.on('error', function(e) {
    log.warn('dyn', "error : " + (JSON.stringify(e)));
    return cc(e);
  });
  if (body) {
    req.write(body);
  }
  return defer.promise;
};

crud = function(path, custom) {
  var methods;
  custom || (custom = {});
  methods = {
    _list: 'GET',
    _create: 'POST',
    _get: 'GET',
    _update: 'PUT',
    _destroy: 'DELETE'
  };
  return _.reduce(_.keys(methods), function(a, x) {
    a[x] || (a[x] = {});
    a[x]._path = function(dyn, data) {
      var cpath, _ref;
      cpath = (custom != null ? (_ref = custom[x]) != null ? _ref.path : void 0 : void 0) || path;
      return _.template(cpath)(data);
    };
    a[x]._call = function(dyn, pathData, bodyData) {
      log.silly('dyn', "api call : " + x + " -> " + path);
      return _request_q(dyn, methods[x], a[x]._path(dyn, pathData), bodyData);
    };
    return a;
  }, {});
};

crudRecord = function(type) {
  return crud("/" + type + "Record/", {
    _list: {
      path: "/" + type + "Record/{{zone}}/{{fqdn}}"
    },
    _create: {
      path: "/" + type + "Record/{{zone}}/{{fqdn}}/"
    },
    _get: {
      path: "/" + type + "Record/{{zone}}/{{fqdn}}/{{id}}"
    },
    _update: {
      path: "/" + type + "Record/{{zone}}/{{fqdn}}/{{id}}"
    },
    _destroy: {
      path: "/" + type + "Record/{{zone}}/{{fqdn}}/{{id}}"
    }
  });
};

crudZone = function() {
  return crud("/Zone/", {
    _list: {
      path: "/Zone/"
    },
    _create: {
      path: "/Zone/{{zone}}/"
    },
    _get: {
      path: "/Zone/{{zone}}/"
    },
    _update: {
      path: "/Zone/{{zone}}/"
    },
    _destroy: {
      path: "/Zone/{{zone}}/"
    }
  });
};

crudGslb = function() {
  return crud("/GSLB/", {
    _list: {
      path: "/GSLBRegion/{{zone}}"
    },
    _create: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    },
    _get: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    },
    _update: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    },
    _destroy: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    }
  });
};

crudGslbRegion = function() {
  return crud("/GSLBRegion/", {
    _list: {
      path: "/GSLBRegion/{{zone}}"
    },
    _create: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    },
    _get: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    },
    _update: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}/{{region_code}}"
    },
    _destroy: {
      path: "/GSLBRegion/{{zone}}/{{fqdn}}"
    }
  });
};

makePromise = function(val) {
  var r;
  r = q.defer();
  r.resolve(val);
  return r.promise;
};

callWithError = function(funProm, description, successFilter, successCase, errorCase) {
  return funProm.then(function(x) {
    return makePromise(successFilter(x[1]) ? (log.silly('dyn', "api call returned successfully : " + (JSON.stringify(x[1]))), successCase(x[1])) : (log.info('dyn', "api call returned error : " + (JSON.stringify(x[1]))), errorCase(x[1])));
  }, function(x) {
    log.warn('dyn', "unexpected error : " + (JSON.stringify(x[1])));
    return errorCase(x);
  });
};

isOk = function(x) {
  return x && (x.status === 'success');
};

identity = function(x) {
  return x;
};

extract = function(key) {
  return function(x) {
    return x != null ? x[key] : void 0;
  };
};

extractData = extract('data');

extractMsgs = extract('msgs');

okBool = function() {
  return true;
};

failBool = function() {
  return false;
};

extractRecords = function(x) {
  if (!(x && x.data)) {
    return [];
  }
  return _(x.data).map(function(r) {
    var v;
    v = r.split("/");
    return {
      type: v[2].replace(/Record$/, ""),
      zone: v[3],
      fqdn: v[4],
      id: v[5]
    };
  });
};

extractZones = function(x) {
  if (!(x && x.data)) {
    return [];
  }
  return _(x.data).map(function(r) {
    var v;
    v = r.split("/");
    return {
      zone: v[3]
    };
  });
};

throwMessages = function(x) {
  throw x.msgs || "unknown exception when calling api";
};

Dyn = function(opts) {
  var allow, defaults, dyn, recordTypes, traffic, whiteList;
  defaults = _.defaults(opts || {}, {
    host: 'api2.dynect.net',
    port: 443,
    prefix: '/REST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'dyn-js v0.0.1'
    },
    token: null
  });
  dyn = {};
  dyn.traffic = {};
  traffic = dyn.traffic;
  dyn.log = log;
  dyn.log.level = "info";
  traffic.defaults = _.clone(defaults);
  traffic.withZone = function(zone) {
    traffic.defaults.zone = zone;
    return traffic;
  };
  traffic.zone = crudZone();
  traffic.zone.list = function() {
    return callWithError(traffic.zone._list._call(traffic, {}, {}), "zone.list", isOk, extractZones, throwMessages);
  };
  traffic.zone.create = function(args) {
    return callWithError(traffic.zone._create._call(traffic, {
      zone: traffic.defaults.zone
    }, args), "zone.create", isOk, extractData, throwMessages);
  };
  traffic.zone.get = function() {
    return callWithError(traffic.zone._list._call(traffic, {
      zone: traffic.defaults.zone
    }, {}), "zone.get", isOk, extractData, throwMessages);
  };
  traffic.zone.destroy = function() {
    return callWithError(traffic.zone._destroy._call(traffic, {
      zone: traffic.defaults.zone
    }, {}), "zone.destroy", isOk, extractMsgs, throwMessages);
  };
  traffic.zone.publish = function() {
    return callWithError(traffic.zone._update._call(traffic, {
      zone: traffic.defaults.zone
    }, {
      publish: true
    }), "zone.publish", isOk, extractData, throwMessages);
  };
  traffic.zone.freeze = function() {
    return callWithError(traffic.zone._update._call(traffic, {
      zone: traffic.defaults.zone
    }, {
      freeze: true
    }), "zone.freeze", isOk, extractData, throwMessages);
  };
  traffic.zone.thaw = function() {
    return callWithError(traffic.zone._update._call(traffic, {
      zone: traffic.defaults.zone
    }, {
      thaw: true
    }), "zone.thaw", isOk, extractData, throwMessages);
  };
  traffic.session = crud("/Session/");
  traffic.session.create = function() {
    return callWithError(traffic.session._create._call(traffic, {}, _.pick(traffic.defaults, 'customer_name', 'user_name', 'password')), "session.create", isOk, function(x) {
      traffic.defaults.token = x.data.token;
      return makePromise(x);
    }, throwMessages);
  };
  traffic.session.destroy = function() {
    return callWithError(traffic.session._destroy._call(traffic, {}, {}), "session.destroy", isOk, function(x) {
      traffic.defaults.token = null;
      return makePromise(x);
    }, throwMessages);
  };
  recordTypes = ['All', 'ANY', 'A', 'AAAA', 'CERT', 'CNAME', 'DHCID', 'DNAME', 'DNSKEY', 'DS', 'IPSECKEY', 'KEY', 'KX', 'LOC', 'MX', 'NAPTR', 'NS', 'NSAP', 'PTR', 'PX', 'RP', 'SOA', 'SPF', 'SRV', 'SSHFP', 'TXT'];
  whiteList = {
    'All': 'list',
    'ANY': 'list',
    'SOA': {
      'list': true,
      'get': true,
      'update': true
    }
  };
  allow = function(x, op) {
    return !whiteList[x] || (_.isString(whiteList[x]) && whiteList[x] === op) || (_.isObject(whiteList[x]) && whiteList[x][op]);
  };
  traffic.record = _.reduce(recordTypes, function(a, x) {
    var type;
    type = "_" + x;
    a[type] = crudRecord(x);
    if (allow(x, 'list')) {
      a[type].list = (function(fqdn) {
        return callWithError(traffic.record[type]._list._call(traffic, {
          zone: traffic.defaults.zone,
          fqdn: fqdn || ''
        }, {}), "record._" + type + ".list", isOk, extractRecords, throwMessages);
      });
    }
    if (allow(x, 'create')) {
      a[type].create = (function(fqdn, record) {
        return callWithError(traffic.record[type]._create._call(traffic, {
          zone: traffic.defaults.zone,
          fqdn: fqdn
        }, record), "record._" + type + ".create", isOk, extractData, throwMessages);
      });
    }
    if (allow(x, 'destroy')) {
      a[type].destroy = (function(fqdn, opt_id) {
        return callWithError(traffic.record[type]._destroy._call(traffic, {
          zone: traffic.defaults.zone,
          fqdn: fqdn,
          id: opt_id || ''
        }, {}), "record._" + type + ".destroy", isOk, extractMsgs, throwMessages);
      });
    }
    if (allow(x, 'get')) {
      a[type].get = (function(fqdn, id) {
        return callWithError(traffic.record[type]._get._call(traffic, {
          zone: traffic.defaults.zone,
          fqdn: fqdn,
          id: id
        }, {}), "record._" + type + ".get", isOk, extractRecords, throwMessages);
      });
    }
    if (allow(x, 'update')) {
      a[type].update = (function(fqdn, id, record) {
        return callWithError(traffic.record[type]._update._call(traffic, {
          zone: traffic.defaults.zone,
          fqdn: fqdn,
          id: id
        }, record), "record._" + type + ".update", isOk, extractData, throwMessages);
      });
    }
    if (allow(x, 'replace')) {
      a[type].replace = (function(fqdn, records) {
        var arg;
        arg = {};
        arg["" + x + "Records"] = records;
        return callWithError(traffic.record[type]._update._call(traffic, {
          zone: traffic.defaults.zone,
          fqdn: fqdn,
          id: ''
        }, arg), "record._" + type + ".replace", isOk, extractData, throwMessages);
      });
    }
    return a;
  }, {});
  traffic.gslb = crudGslb();
  traffic.gslb.list = function(detail) {
    return callWithError(traffic.gslb._list._call(traffic, {
      zone: traffic.defaults.zone
    }, {
      detail: detail || 'N'
    }), "gslb.list", isOk, extractData, throwMessages);
  };
  traffic.gslb.get = function(fqdn) {
    return callWithError(traffic.gslb._get._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {}), "gslb.get", isOk, extractData, throwMessages);
  };
  traffic.gslb.create = function(fqdn, opts) {
    return callWithError(traffic.gslb._create._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, opts), "gslb.create", isOk, extractData, throwMessages);
  };
  traffic.gslb.destroy = function(fqdn) {
    return callWithError(traffic.gslb._destroy._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {}), "gslb.destroy", isOk, extractData, throwMessages);
  };
  traffic.gslb.update = function(fqdn, opts) {
    return callWithError(traffic.gslb._update._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, opts), "gslb.update", isOk, extractData, throwMessages);
  };
  traffic.gslb.activate = function(fqdn) {
    return callWithError(traffic.gslb._update._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {
      activate: true
    }), "gslb.activate", isOk, extractData, throwMessages);
  };
  traffic.gslb.deactivate = function(fqdn) {
    return callWithError(traffic.gslb._update._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {
      deactivate: true
    }), "gslb.deactivate", isOk, extractData, throwMessages);
  };
  traffic.gslb.recover = function(fqdn) {
    return callWithError(traffic.gslb._update._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {
      recover: true
    }), "gslb.recover", isOk, extractData, throwMessages);
  };
  traffic.gslb.recoverip = function(fqdn, opts) {
    return callWithError(traffic.gslb._update._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, opts), "gslb.recoverip", isOk, extractData, throwMessages);
  };
  traffic.gslbRegion = crudGslbRegion();
  traffic.gslbRegion.list = function(detail) {
    return callWithError(traffic.gslbRegion._list._call(traffic, {
      zone: traffic.defaults.zone
    }, {
      detail: detail || 'N'
    }), "gslbRegion.list", isOk, extractData, throwMessages);
  };
  traffic.gslbRegion.get = function(fqdn) {
    return callWithError(traffic.gslbRegion._get._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {}), "gslbRegion.get", isOk, extractData, throwMessages);
  };
  traffic.gslbRegion.create = function(fqdn, opts) {
    return callWithError(traffic.gslbRegion._create._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, opts), "gslbRegion.create", isOk, extractData, throwMessages);
  };
  traffic.gslbRegion.destroy = function(fqdn) {
    return callWithError(traffic.gslbRegion._destroy._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn
    }, {}), "gslbRegion.destroy", isOk, extractData, throwMessages);
  };
  traffic.gslbRegion.update = function(fqdn, region_code, opts) {
    return callWithError(traffic.gslbRegion._update._call(traffic, {
      zone: traffic.defaults.zone,
      fqdn: fqdn,
      region_code: region_code
    }, opts), "gslbRegion.update", isOk, extractData, throwMessages);
  };
  return dyn;
};

module.exports = Dyn;
