var bodyParser = require('body-parser');
var fs = require('fs');
var wpi = require('wiring-pi');
var RaspiCam = require("raspicam");
var request = require('request');
var requestJson = require('request-json');
var FormData = require('form-data');
var path = require('path');
var shell = require('python-shell');

// GPIO pin of the button
var configPin = 7;

wpi.setup('wpi');
var started = false;
var clock = null;

wpi.pinMode(configPin, wpi.INPUT);
wpi.pullUpDnControl(configPin, wpi.PUD_UP);
wpi.wiringPiISR(configPin, wpi.INT_EDGE_BOTH, function() {
  console.log("hhhhhh");
  
  if (wpi.digitalRead(configPin)) {
    if (false === started) {
      started = true;
      clock = setTimeout(handleButton, 3000);
    }
  }
  else {
    started = false;
    clearTimeout(clock);
  }
});

function handleButton() {
  if (wpi.digitalRead(configPin)) {
    console.log('OK');
    takePhoto();
  }
}

setInterval(function(){
  shell.run('sense.py', function(err,result) {
    if (err) throw err;
    console.log(result[0]);
    var distance = Number(result[0]);
    if (distance < 200) {
      console.log("Current distance is: " + distance + " close enough to taka a photo");
      takePhoto();
    }
  });
  }, 5000);

function takePhoto() {
  var camera = new RaspiCam({
       mode: "photo",
       output: "./photo/image.png",
       encoding: "png",
       timeout: 0 // take the picture immediately
   });

   camera.on("start", function (err, timestamp) {
       console.log("photo started at " + timestamp);
   });

   camera.on("read", function(err, timestamp, filename) {
       console.log("photo image captured with filename: " + filename);
       //camera.stop();
       setTimeout(function() {
         camera.stop();
       }, 1000);
   });

   camera.on("exit", function (timestamp) {
       console.log("photo child process has exited at " + timestamp);
       
       var img = fs.readFileSync('./photo/image.png');
       
       //var form = new FormData();
       //form.append("folder_id", "0");
       //form.append("filename", fs.createReadStream(path.join(__dirname, "/photo/image.png")));

       var options = {
          uri: 'https://westus.api.cognitive.microsoft.com/vision/v1.0/analyze?visualFeatures=Description&language=en',
          method: 'POST',
          //json: {
          //   "url": "/photo/image.png"
          //},
          headers: {
              // Request headers
              "Content-Type": "application/octet-stream",
              "Ocp-Apim-Subscription-Key": "5cb654780402451dbb6607631d6a4808"
          },
          body: img
       };

       request(options, function (error, response, body) {
         if (!error && response.statusCode == 200) {
             console.log(body);
	try {
             var data = JSON.parse(body);
             console.log(typeof(data));
             sendData(data);
	}catch(e) {console.log("parse error: " + e);}
         } else {
             console.log(error);
             console.log(response);
         }
       });

   });

   camera.start();

}

function sendData(data) {

  var client = requestJson.createClient('http://localhost:5001/');
  client.post('imageData/', data, function(error, response, body) {
    if (!error && response.statusCode == 200) {
             console.log(body);
    } else {
             console.log(error);
    }
  })
  
  /*
  var options = {
          uri: 'http://172.29.92.134:5001/imageData/',
          method: 'POST',
          headers: {
              // Request headers
              "Content-Type": "application/json",
          },
          body: data,
          json: true
       };

       request(options, function (error, response, body) {
         if (!error && response.statusCode == 200) {
             console.log(body);
         } else {
             console.log(error);
         }
       });
  */
}



