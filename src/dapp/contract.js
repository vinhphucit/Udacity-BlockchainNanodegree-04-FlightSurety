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
        this.account = null;
        this.airlines = [];
        this.passengers = [];
    }

    async initialize(callback) {
        self = this;
        await window.ethereum.enable();


        this.web3.eth.getAccounts(async (error, accts) => {
            self.owner = accts[0];
            // self.account = accts[1];
            console.log('owner: ', self.owner)
            let accountsOnEnable = await ethereum.request({ method: 'eth_requestAccounts' });
            console.log('account: ', accountsOnEnable)
            self.account = accountsOnEnable[0];
            let counter = 1;

            while (self.airlines.length < 5) {
                self.airlines.push(accts[counter++]);
            }

            while (self.passengers.length < 5) {
                self.passengers.push(accts[counter++]);
            }

            callback();
        });

        window.ethereum.on('accountsChanged', async function () {
            let accountsOnEnable = await ethereum.request({ method: 'eth_requestAccounts' });
            console.log(accountsOnEnable);
            self.account = accountsOnEnable[0];
            console.log('changed to account: ', self.account)
        });

    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner }, callback);
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
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    fetchRegisteredAirlineAddresses(callback) {
        let self = this;
        self.flightSuretyApp.methods.getAirlineAddresses().call({}, (error, result) => {
            callback(error, result);
        });
    }

    fetchActivatedAirlineAddresses(callback){
        let self = this;
        self.flightSuretyApp.methods.getActivatedAirlines().call({}, (error, result) => {
            callback(error, result);
        });
    }
    fetchFundByAirline(address, callback) {
        let self = this;
        self.flightSuretyApp.methods.getFundByAirline(address).call({ from: self.owner }, (error, result) => {
            callback(error, self.web3.utils.fromWei(result, "ether").toString());
        });
    }
    getFlightKeys(callback) {
        let self = this;
        self.flightSuretyApp.methods.getFlightKeys().call({}, (error, result) => {
            callback(error, result);
        });
    }
    getFlightByKey(key, callback) {
        let self = this;
        self.flightSuretyApp.methods.getFlightInfo(key).call({}, (error, result) => {
            callback(error, result);
        });
    }
    registerAirline(airline,name, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerAirline(airline, name)
            .send({ from: self.account , gas: 999999999}, (error, result) => {
                callback(error, result);
            });
    }
    fundAirline(amount, callback) {
        let self = this;
        console.log('fundAirline with account', self.account);
        let amountInWei = self.web3.utils.toWei(amount, "ether").toString();
        self.flightSuretyApp.methods
            .fundAirline()
            .send({ from: self.account, value: amountInWei ,gas: 999999999 }, (error, result) => {
                callback(error, result);
            });
    }
    registerFlight(flightNumber, timestamp, callback) {
        let self = this;
        console.log('registerFlight with account', self.account);
        self.flightSuretyApp.methods
            .registerFlight(flightNumber, timestamp)
            .send({ from: self.account, gas: 999999999 }, (error, result) => {
                callback(error, result);
            });
    }

    fetchFlightStatus(flightKey, callback) {
        let self = this;
        console.log('fetchFlightStatus for ', flightKey);
        self.flightSuretyApp.methods
            .fetchFlightStatus(flightKey)
            .send({ from: self.account }, (error, result) => {
                callback(error, result);
            });
    }
    buyInsurance(flightKey, amount, callback) {
        let self = this;
        console.log('buyInsurance for ', self.account);
        let amountInWei = self.web3.utils.toWei(amount, "ether").toString();
        self.flightSuretyApp.methods
            .buyInsurance(flightKey)
            .send({ from: self.account, value: amountInWei, gas: 999999999 }, (error, result) => {
                callback(error, result);
            });
    }
    getFundedInsuranceAmount(flightKey, callback) {
        let self = this;
        self.flightSuretyApp.methods.getFundedInsuranceAmount(flightKey, self.account).call((error, result) => {
            callback(error, self.web3.utils.fromWei(result.amount, "ether").toString(), self.web3.utils.fromWei(result.claimAmount, "ether").toString());
            // callback(error, result);
        });
    }
    getWithdrawableInsurance(callback) {
        let self = this;
        self.flightSuretyApp.methods.getWithdrawableInsurance().call({ from: self.account, gas: 999999999 }, (error, result) => {
            callback(error, result);
        });
    }
    withdraw(callback) {
        let self = this;
        self.flightSuretyApp.methods.withdraw().send({ from: self.account, gas: 999999999 }, (error, result) => {
            callback(error, result);
        });
    }
}

