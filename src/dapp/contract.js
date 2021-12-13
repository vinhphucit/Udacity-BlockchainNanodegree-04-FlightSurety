import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    async initialize(callback) {
        await window.ethereum.enable();
        let accountsOnEnable = await ethereum.request({method: 'eth_requestAccounts'});
        
        this.web3.eth.getAccounts((error, accts) => {           
            this.owner = accts[0];
            this.account = accts[1];
            console.log('owner: ', this.owner)
            console.log('account: ', this.account)
            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
        self = this;
        window.ethereum.on('accountsChanged', async function  () {
            var accountsOnEnable = await ethereum.request({method: 'eth_requestAccounts'});
            this.account = accountsOnEnable;
            console.log('changed to account: ', this.account)
        });
        
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    fetchRegisteredAirlineAddresses(callback){
        let self = this;
        self.flightSuretyApp.methods.getRegisteredAirlineAddresses().call({}, (error, result) => {
            callback(error, result);
        });
    }
    fetchFundByAirline(address, callback){
        let self = this;
        self.flightSuretyApp.methods.getFundByAirline(address).call({ from: self.owner}, (error, result) => {
            callback(error, self.web3.utils.fromWei(result, "ether").toString());
        });
    }
    getFlightKeys(callback){
        let self = this;
        self.flightSuretyApp.methods.getFlightKeys().call({}, (error, result) => {
            callback(error,result);
        });
    }
    getFlightByKey(key, callback){
        let self = this;
        self.flightSuretyApp.methods.getFlightByKey(key).call({}, (error, result) => {
            callback(error,result);
        });
    }
    registerAirline(airline,callback){        
        let self = this;
        console.log('register airline with account ', this.account)
        self.flightSuretyApp.methods
            .registerAirline(airline)
            .send({from: self.account}, (error, result) => {
                callback(error, result);
            });
    }
    fundAirline(amount,callback){        
        let self = this;
        console.log('fund airline by account: ', self.account)
        let amountInWei = self.web3.utils.toWei(amount, "ether").toString();
        self.flightSuretyApp.methods
            .fundAirline()
            .send({ from: self.account, value: amountInWei}, (error, result) => {
                callback(error, result);
            });
    }
    registerFlight(flightNumber, timestamp, callback){
        let self = this;        
        self.flightSuretyApp.methods
            .registerFlight(this.web3.utils.fromAscii(flightNumber), timestamp)
            .send({ from: self.account}, (error, result) => {
                callback(error, result);
            });
    }
}

