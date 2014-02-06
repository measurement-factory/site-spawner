window.addEventListener("load", init, false);

var websocketUrl = "ws://localhost:3000"; // User defines

var websocket = null;
var received = 0;
var testIDArray = [];
var chart = null;
var tests = { vars: {} };
var timeoutID = null;
var updateInterval = 1;

var serversOpen = 0;

if (!Array.contains) {
	Array.prototype.contains = function (needle) {
		for (var i = this.length - 1; i >= 0; i--) {
			if (this[i] == needle) {
				return true;
			}
		}
		return false;
	};
}

function init()	{
	webSocket(websocketUrl); // Creates websocket, assigns functions to call on events.
	initChart();

	document.getElementById('u-interval').value = updateInterval;
	document.getElementById('u-interval').addEventListener("input", function(){
		clearTimeout(timeoutID);
		update();
	}, false);

	update();
}

function update() {
	updateInterval = Number(document.getElementById('u-interval').value);
	if (updateInterval > 0 && serversOpen > 0) {
		renderChart();
	}
	timeoutID = setTimeout(update, updateInterval*1000);
}

function webSocket(wsUri) {
	websocket = new WebSocket(wsUri);
	websocket.onopen    = function (event) { onOpen(event); };
	websocket.onclose   = function (event) { onClose(event); };
	websocket.onmessage = function (event) { onMessage(event); };
	// websocket.onerror   = function (event) { onError(event); };
}

function initChart() {
	chart = $.jqplot('myChart', [[null]], {
		highlighter: {
			show: true,
			sizeAdjust: 7.5
		},
		axes: {
			xaxis: {
				renderer: $.jqplot.DateAxisRenderer,
				rendererOptions: {
					tickOptions: {
						formatString: '%H:%M:%S'
					}
				}
			}
		},
		axesDefaults: {
			// By default, this sets x-axis label to be sideways.
			labelRenderer: $.jqplot.CanvasAxisLabelRenderer
		},
		seriesDefaults: {
			lineWidth: 1,
			markerOptions: {
				style: 'circle',
				size: 3,
			},
		},
		legend: {
			renderer: $.jqplot.EnhancedLegendRenderer,
			show: true,
			placement: 'outside',
			marginTop: '60px',
			location: 's',
		},
		cursor: {
			show: true,
			zoom: true,
			tooltipLocation: 'sw'
		}
	});
}

function renderChart() {
	if (chart.plugins.cursor._zoom.isZoomed || document.querySelector('#myChart:hover'))  {
		return; // Exits out of function if we are called and do not need to replot,
				// due to above conditions.
	}

	var chartData = [];
	var seriesData = [];

	var axisLabels = { x: 'Time', y: document.getElementById('data-options').selectedOptions[0].value };

	for (var testID in tests) {
		if (tests.hasOwnProperty(testID)) {
			var test = tests[testID];

			var data = null;

			if (axisLabels.y == 'Rate') {
				data = test.rate_data;
			} else if (axisLabels.y == 'Transaction Count') {
				data = test.xactCount_data;
			} else if (axisLabels.y == 'Duration') {
				data = test.duration_data;
			}

			chartData.push(data);
			seriesData.push({label: 'Test #' + testID + ' (' + test.runTime + ')'});
		}
	}

	var option = document.getElementById('line-opts').selectedOptions[0].value;
	var smoothing = (option == 'Smoothing');

	chart.replot({
		resetAxes: true,
		data: chartData,
		series: seriesData,
		seriesDefaults: {
			showLine: (option != 'None'),
			showMarker: document.getElementById('data-points').checked,
			rendererOptions: {
				smooth: smoothing,
				constrainSmoothing: smoothing
			}
		},
		axes: {
			xaxis: {
				label: axisLabels.x,
			},
			yaxis: {
				label: axisLabels.y,
			}
		},
	});
}

function onOpen(event) {
	// writeToScreen("<span style=\"color: green;\">CONNECTED: " + event.target.URL + "</span>");
	++serversOpen;
}

function onClose(event)  {
	// writeToScreen("<span style=\"color: red;\">CLOSED: " + event.target.URL + "</span>");
	--serversOpen;
}

// function onError(event)  {
// 	// writeToScreen('<span style="color: red;">ERROR: ' + event.data + ', Socket URL: ' + event.target.URL + '</span>');
// }

function onMessage(event)  {
	++received;

	grokBlob(event.data); // grokBlob passes output to handleStats.
}

function handleStats(stats) {
	var testID = stats.testID.toString();
	if (tests[testID] === undefined) {
		tests[testID] = {
			xactCount_data: [],
			duration_data: [],
			rate_data: [],
			stats: [],
			series: testIDArray.length,
		};
	}

	stats.rate = Number(stats.xactCount/stats.duration);

	tests[testID].stats.push(stats);

	// Multiplication by 1000 done to convert to milliseconds, otherwise jqplot dateAxisRenderer does not work.
	tests[testID].xactCount_data.push([stats.timeStamp*1000, stats.xactCount]);
	tests[testID].duration_data.push([stats.timeStamp*1000, stats.duration]);
	tests[testID].rate_data.push([stats.timeStamp*1000, stats.rate]);

	var runTime = new Date((stats.timeStamp - stats.startTime)*1000);
	var runTimeMinutes = runTime.getMinutes();
	if (runTimeMinutes < 10) {
		runTimeMinutes = '0' + runTimeMinutes.toString();
	}
	tests[testID].runTime = runTime.getHours() + ':' + runTimeMinutes;

	if (!testIDArray.contains(testID)) {
		testIDArray.push(testID);
	}
}

function grokBlob(blob) {
	// See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Typed_arrays
	// then https://developer.mozilla.org/en-US/docs/Web/JavaScript/Typed_arrays/DataView

	var reader = new window.FileReader();
	reader.readAsArrayBuffer(blob);

	reader.onloadend = function() {
		var dataView = new DataView(reader.result);

		var offset = 0;


		var testID =
			// convert two 32-bit integers into a 64-bit number
			dataView.getUint32(offset, false)*Math.pow(2, 4*8) /* 0xFFFF */ +
			dataView.getUint32(offset+=4, false);

		var startTime =
			dataView.getUint32(offset+=4, false)*Math.pow(2, 4*8) /* 0xFFFF */ +
			dataView.getUint32(offset+=4, false);

		var timeStamp =
			dataView.getUint32(offset+=4, false)*Math.pow(2, 4*8) /* 0xFFFF */ +
			dataView.getUint32(offset+=4, false);

		var xactCount =
			dataView.getInt32(offset+=4, false)*Math.pow(2, 4*8) /* 0xFFFF */ +
			dataView.getUint32(offset+=4, false);

		var duration =
			dataView.getUint32(offset+=4, false) +     // seconds
			dataView.getUint32(offset+=4, false)/1e6;  // microseconds

		var stats = {
			testID: testID,
			byteLength: reader.result.byteLength,
			blobSize: blob.size,
			xactCount: xactCount,
			duration: duration,
			startTime: startTime,
			timeStamp: timeStamp,
		};

		handleStats(stats);
	};
}
