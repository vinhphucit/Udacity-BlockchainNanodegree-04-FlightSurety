import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import "babel-polyfill";
let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let oracles = [];

async function registerOracles() {
  console.log('START registerOracles')
  const REGISTRATION_FEE = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  let accounts = await web3.eth.getAccounts();
  let numberOfOracles = 20;
  if (accounts.length < numberOfOracles) {
    numberOfOracles = accounts.length;
  }

  for (var i = 0; i < numberOfOracles; i++) {
    oracles.push(accounts[i]);
    await flightSuretyApp.methods.registerOracle().send({
      from: accounts[i],
      value: REGISTRATION_FEE,
      gas: 999999999
    });
  }
}
function getRandomInt(max) {
  return Math.floor(Math.random() * max);
}

async function submitOracleResponse(airline, flight, timestamp) {
  for (var i = 0; i < oracles.length; i++) {
    //generate random response
    var statusCode = getRandomInt(5) * 10;
    // var statusCode = 20;
    var indexes = await flightSuretyApp.methods.getMyIndexes().call({ from: oracles[i] });
    for (var j = 0; j < indexes.length; j++) {
      try {
        await flightSuretyApp.methods.submitOracleResponse(
          indexes[j], airline, flight, timestamp, statusCode
        ).send({ from: oracles[i], gas: 999999999 });
      } catch (e) {
        console.log('error submitOracleResponse', indexes[j], airline, flight, timestamp, statusCode)
        // console.log('submitOracleResponse error: ', e);
      }
    }
  }
}

function eventsListener() {
  console.log('================================= START eventsListener=================================')

  flightSuretyApp.events.DebuggerEvent({}, debuggerEventListener)
  flightSuretyApp.events.FlightStatusInfo({}, flightStatusInfoListener);
  flightSuretyApp.events.OracleReport({}, oracleReportListener);
  flightSuretyApp.events.OracleRegistered({}, oracleRegisteredListener);
  flightSuretyApp.events.OracleRequest({}, oracleRequestListener);

}

flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, function (error, event) {
  logEvent(error, event);
});

function debuggerEventListener(err, contractEvent) {
  logEvent(err, contractEvent);
}
function airlineReisteredListener(err, contractEvent) {
  logEvent(err, contractEvent);
}
function flightStatusInfoListener(err, contractEvent) {
  logEvent(err, contractEvent);
}

function oracleReportListener(err, contractEvent) {
  logEvent(err, contractEvent);
}
function oracleRegisteredListener(err, contractEvent) {
  logEvent(err, contractEvent);
}
async function oracleRequestListener(err, contractEvent) {
  logEvent(err, contractEvent);
  if (!err) {
    await submitOracleResponse(
      contractEvent.returnValues[1], // airline
      contractEvent.returnValues[2], // flight
      contractEvent.returnValues[3] // timestamp
    );
  }
}
function logEvent(err, contractEvent) {
  if (err) {
    console.error('logEvent error: ', err);
    return;
  }
  const {
    event,
    returnValues,
  } = contractEvent;
  console.log('event: ', event, 'returnValues', returnValues);
}
registerOracles();
eventsListener()
const app = express();
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

export default app;