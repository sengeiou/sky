<#import "/spring.ftl" as spring />
<!doctype html>
<html lang="en">
<head>
  <base href="${basePath}">
  <meta charset="utf-8" />
  <title>断路器监控</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <link rel="stylesheet" type="text/css" href="css/global.css" />
  <link rel="stylesheet" type="text/css" href="css/monitor.css" />
  <script type="text/javascript" src="<@spring.url '/webjars/d3js/3.4.11/d3.min.js'/>" ></script>
  <script type="text/javascript" src="<@spring.url '/webjars/jquery/2.1.1/jquery.min.js'/>" ></script>
  <script type="text/javascript" src="js/jquery.tinysort.min.js"></script>
  <script type="text/javascript" src="js/tmpl.js"></script>
  <script type="text/javascript" src="components/hystrixCommand/hystrixCommand.js"></script>
  <link rel="stylesheet" type="text/css" href="components/hystrixCommand/hystrixCommand.css" />
  <script type="text/javascript" src="components/hystrixThreadPool/hystrixThreadPool.js"></script>
  <link rel="stylesheet" type="text/css" href="components/hystrixThreadPool/hystrixThreadPool.css" />
</head>
<body>
<div id="header">
  <h2><span id="title_name"></span></h2>
</div>

<div class="container">
  <div class="row">
    <div class="menubar">
      <div class="title">
        熔断
      </div>
      <div class="menu_actions">
        Sort:
        <a href="javascript://" onclick="hystrixMonitor.sortByErrorThenVolume();">Error then Volume</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortAlphabetically();">Alphabetical</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByVolume();">Volume</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByError();">Error</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByLatencyMean();">Mean</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByLatencyMedian();">Median</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByLatency90();">90</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByLatency99();">99</a> |
        <a href="javascript://" onclick="hystrixMonitor.sortByLatency995();">99.5</a>
      </div>
      <div class="menu_legend">
        <span class="success">成功</span> | <span class="shortCircuited">短路</span> | <span class="badRequest">Bad</span> | <span class="timeout">超时</span> | <span class="rejected">拒绝</span> | <span class="failure">失败</span> | <span class="errorPercentage">错误率</span>
      </div>
    </div>
  </div>
  <div id="dependencies" class="row dependencies"><span class="loading">加载中 ...</span></div>

  <div class="spacer"></div>

  <div class="row">
    <div class="menubar">
      <div class="title">
        线程池
      </div>
      <div class="menu_actions">
        Sort: <a href="javascript://" onclick="dependencyThreadPoolMonitor.sortAlphabetically();">Alphabetical</a> |
        <a href="javascript://" onclick="dependencyThreadPoolMonitor.sortByVolume();">Volume</a> |
      </div>
    </div>
  </div>
  <div id="dependencyThreadPools" class="row dependencyThreadPools"><span class="loading">加载中 ...</span></div>
</div>



<script>
  /**
   * Queue up the monitor to start once the page has finished loading.
   *
   * This is an inline script and expects to execute once on page load.
   */

    // commands
  var hystrixMonitor = new HystrixCommandMonitor('dependencies', {includeDetailIcon:false});

  var stream = getUrlVars()["stream"];

  console.log("Stream: " + stream)

  if(stream != undefined) {
    if(getUrlVars()["delay"] != undefined) {
      stream = stream + "&delay=" + getUrlVars()["delay"];
    }

    var commandStream = "${contextPath}/proxy.stream?origin=" + stream;
    var poolStream = "${contextPath}/proxy.stream?origin=" + stream;

    if(getUrlVars()["title"] != undefined) {
      $('#title_name').text("目标流: " + decodeURIComponent(getUrlVars()["title"]))
    } else {
      $('#title_name').text("目标流: " + decodeURIComponent(stream))
    }
  }
  console.log("Command Stream: " + commandStream)

  $(window).load(function() { // within load with a setTimeout to prevent the infinite spinner
    setTimeout(function() {
      if(commandStream == undefined) {
        console.log("commandStream is undefined")
        $("#dependencies .loading").html("The 'stream' argument was not provided.");
        $("#dependencies .loading").addClass("failed");
      } else {
        // sort by error+volume by default
        hystrixMonitor.sortByErrorThenVolume();

        // start the EventSource which will open a streaming connection to the server
        var source = new EventSource(commandStream);

        // add the listener that will process incoming events
        source.addEventListener('message', hystrixMonitor.eventSourceMessageListener, false);

        //	source.addEventListener('open', function(e) {
        //		console.console.log(">>> opened connection, phase: " + e.eventPhase);
        //	    // Connection was opened.
        //	}, false);

        source.addEventListener('error', function(e) {
          $("#dependencies .loading").html("Unable to connect to Command Metric Stream.");
          $("#dependencies .loading").addClass("failed");
          if (e.eventPhase == EventSource.CLOSED) {
            // Connection was closed.
            console.log("Connection was closed on error: " + JSON.stringify(e));
          } else {
            console.log("Error occurred while streaming: " + JSON.stringify(e));
          }
        }, false);
      }
    },0);
  });

  // thread pool
  var dependencyThreadPoolMonitor = new HystrixThreadPoolMonitor('dependencyThreadPools');

  $(window).load(function() { // within load with a setTimeout to prevent the infinite spinner
    setTimeout(function() {
      if(poolStream == undefined) {
        console.log("poolStream is undefined")
        $("#dependencyThreadPools .loading").html("The 'stream' argument was not provided.");
        $("#dependencyThreadPools .loading").addClass("failed");
      } else {
        dependencyThreadPoolMonitor.sortByVolume();

        // start the EventSource which will open a streaming connection to the server
        var source = new EventSource(poolStream);

        // add the listener that will process incoming events
        source.addEventListener('message', dependencyThreadPoolMonitor.eventSourceMessageListener, false);

        //	source.addEventListener('open', function(e) {
        //		console.console.log(">>> opened connection, phase: " + e.eventPhase);
        //	    // Connection was opened.
        //	}, false);

        source.addEventListener('error', function(e) {
          $("#dependencies .loading").html("Unable to connect to Command Metric Stream.");
          $("#dependencies .loading").addClass("failed");
          if (e.eventPhase == EventSource.CLOSED) {
            // Connection was closed.
            console.log("Connection was closed on error: " + e);
          } else {
            console.log("Error occurred while streaming: " + e);
          }
        }, false);
      }
    },0);
  });

  //Read a page's GET URL variables and return them as an associative array.
  // from: http://jquery-howto.blogspot.com/2009/09/get-url-parameters-values-with-jquery.html
  function getUrlVars()
  {
    var vars = [], hash;
    var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
    for(var i = 0; i < hashes.length; i++)
    {
      hash = hashes[i].split('=');
      vars.push(hash[0]);
      vars[hash[0]] = hash[1];
    }
    return vars;
  }

</script>


</body>
</html>
