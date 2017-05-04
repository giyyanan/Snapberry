var express = require('express'),
  app = express(),
  config = require('./config'),
  firebase = require('firebase'),
  bodyParser = require('body-parser');

//Initialize Firebase
firebase.initializeApp(config.firebase_config);

var userDataRef = firebase.database().ref('user-data');

app.use(bodyParser.urlencoded({extended: false}));

// parse application/json
app.use(bodyParser.json());

app.use(function (req, res, next) {
    // Website you wish to allow to connect
    res.setHeader('Access-Control-Allow-Origin', 'http://localhost:8000');
    // Request methods you wish to allow
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE');
    // Request headers you wish to allow
    res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type');
    // Set to true if you need the website to include cookies in the requests sent
    // to the API (e.g. in case you use sessions)
    res.setHeader('Access-Control-Allow-Credentials', true);

    // Pass to next layer of middleware
    next();
});

app.get('/', function(req, res) {
  res.json({msg: "welcome!"});
});

//Get Image Data in JSON Format
app.get('/:node',function(req,res){
  firebase.database().ref('/').once('value').then(function(snapshot){
    // console.log(snapshot.val());
    // console.log(snapshot.key);
    var data = snapshot.val();
    var node = req.params.node;
    console.log(node);
    console.log(Object.keys(data));
    if (data[node]) {
      res.json(data[node]);
    } else {
      res.json({msg: "data not found!"})
    }

  });
});

//Recieve image data in JSON Format
app.post('/imageData', function(req, res) {
  console.log(req.body);

  if (!req.body) res.send("error for posting image data!");
  var date2 = Date.now();
  userDataRef.child("user_1/scenes").child(date2).child('description').set(req.body.description.captions[0].text).then(function(){return userDataRef.child("user_1/scenes").child(date2).once('value');}).then(function(snapshot) {
    console.log(snapshot.val());
    console.log(snapshot.key);

    res.json({message: "Insert new record successfully!"});
  });
});

app.listen(config.port);
// console.log(firebase.database())

console.log('Server Up on: ' + config.port);

