# Dyn SDK for Node.JS - Developer Preview

NOTE: This is SDK is brand new - we welcome your feedback! Please
reach out via pull request or GitHub issue.

Making DNS Updates is as easy as:

    var Dyn   = require('dyn-js');
    var async = require('async-q');

    var dynClient = Dyn({traffic:{customer_name:'yourcustomername',user_name:'yourusername',password:'yourpassword'}})
    var dyn = dynClient.traffic.withZone('example.com')

    var errorCallback = function() { console.log('FAIL', arguments); };

    // Using an Async Series of Operations
    async.series([
      function() { dyn.session.create() },
      function() {
        return dyn.zone.list().then(function (x) {
          console.log('RESULT', "got zones: " + JSON.stringify(x));
          return x;
        });
      },
      function() { dyn.record._All.list(); },
      function() { dyn.record._A.get('local.example.com'); },
      function() { dyn.record._A.destroy('local.example.com'); },
      function() { dyn.record._A.replace('local.example.com',[{rdata:{address:'127.0.0.1'}},{rdata:{address:'127.0.0.9'}}]); },
      function() { dyn.zone.publish(); },
      function() { dyn.session.destroy(); }
    ]).then(function() {
      arguments[0].forEach(function(x) {
        console.log('RESULT', "finished : " + JSON.stringify(x));
      });
    }, errorCallback);

    // Using Chained Promise 'then' style
    dyn.record._A.get('local.example.com').then(function(data) {
      console.log('got data', data);
      return dyn.record._A.replace('local.example.com',[{rdata:{address:'127.0.0.1'}},{rdata:{address:'127.0.0.9'}}]);
    }).then(function() {
      return dyn.zone.publish();
    }).then(function() {
      return dyn.session.destroy();
    });

Using Messaging is as easy as:

    var Dyn   = require('dyn-js');
    var async = require('async-q');

    var dynClient = Dyn({messaging:{apikey:'yourapikey'}});
    var dyn = dynClient.messaging;

    async.series([
      function() {
        return dyn.senders.create("foo@bars.com", 3).then(function(x) {
          log.info('RESULT', "created sender: " + (JSON.stringify(x)));
          return x;
        });
      }, function() {
        return dyn.senders.status("foo@bars.com").then(function(x) {
          log.info('RESULT', "got sender status: " + (JSON.stringify(x)));
          return x;
      }, function() {
        return dyn.senders.details("foo@bars.com").then(function(x) {
          log.info('RESULT', "got sender detail: " + (JSON.stringify(x)));
          return x;
        });
      }
    ]).then(function() {
      return _(arguments[0]).forEach(function(x) {
        return log.info('RESULT', "finished : " + (JSON.stringify(x)));
      });
    }, fail);
    
    async.series([
      function() {
        return dyn.accounts.create("example@foo.com", "secret", "bar", "1234567890").then(function(x) {
          log.info('RESULT', "created account: " + (JSON.stringify(x)));
          return x;
        });
      }, function() {
        return dyn.accounts.list().then(function(x) {
          log.info('RESULT', "got accounts: " + (JSON.stringify(x)));
          return x;
        });
      }, function() {
        return dyn.accounts.list_xheaders().then(function(x) {
          log.info('RESULT', "got xheaders: " + (JSON.stringify(x)));
          return x;
        });
      }, function() {
        return dyn.accounts.update_xheaders("X-Test1", "X-AnotherTest2", "X-Testing3", "X-FullyTested4").then(function(x) {
          log.info('RESULT', "updated xheaders: " + (JSON.stringify(x)));
          return x;
        });
      }
    ]).then(function() {
      return _(arguments[0]).forEach(function(x) {
        return log.info('RESULT', "finished : " + (JSON.stringify(x)));
      });
    }, fail);
    
    async.series([
      function() {
        return dyn.recipients.activate("foo@bars.com").then(function(x) {
          log.info('RESULT', "activated recipient: " + (JSON.stringify(x)));
          return x;
        });
      }, function() {
        return dyn.recipients.status("foo@bars.com").then(function(x) {
          log.info('RESULT', "got status of recipient: " + (JSON.stringify(x)));
          return x;
        });
      }
    ]).then(function() {
      return _(arguments[0]).forEach(function(x) {
        return log.info('RESULT', "finished : " + (JSON.stringify(x)));
      });
    }, fail);
    
    async.series([
      function() {
        return dyn.send_mail.create("foo@bars.com", "recipient@destination.com", "hello, new js api", "it works!").then(function(x) {
          log.info('RESULT', "sent mail: " + (JSON.stringify(x)));
          return x;
        });
      }
    ]).then(function() {
      return _(arguments[0]).forEach(function(x) {
        return log.info('RESULT', "finished : " + (JSON.stringify(x)));
      });
    }, fail);

# API Endpoints Supported

* Traffic - Session API: create/destroy
* Traffic - Record API: AAAA A CNAME DNSKEY DS KEY LOC MX NS PTR RP SOA SRV TXT
* Traffic - GSLB API: list/get/create/update/destroy
* Traffic - GSLB Region API: list/get/create/update/destroy
* Traffic - Zone API: list/get/create/destroy/publish/freeze/thaw
* Traffic - HttpRedirect API: list/get/create/update/destroy
* Messaging - All Endpoints Supported

# Examples

* See the "examples" folder for more comprehensive examples

## License

(The MIT License)

Copyright (c) Dynamic Network Services, Inc
Copyright (c) frisB.com &lt;play@frisb.com&gt;

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
