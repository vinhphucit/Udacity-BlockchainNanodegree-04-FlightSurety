
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');

var Config = async function (accounts) {

    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0xd0e8db080c43ACF428bcfe771779E985181506B6",
        "0xB633c3a1570DAA9546BF35399aB0Aa6067481Dcb",
        "0xEEf5f2d1C217AE6391819240bB373AFb9af88b03",
        "0x11eDD75480622a22710c51063c10408E4e7136FF",
        "0xc8d31cfE810eB1f9603E8d52508BEa5f87698586",
        "0x8FAb077fbF711229D9F37953486ca510173E8d56",
        "0x3b18139E0A51e88C4892b6816464Fb956Fe63eA2",
        "0xf3b68e46EF9363948dd1026439743CC7db1D60f7",
        "0x2B8137C0E70aeC0859ee536aFbC89e71E40955C3",
        "0x480F79C20B98046E9eB66fd54D4abDBf6cE65a86",
    ];


    let owner = accounts[0];
    let firstAirline = accounts[1];

    let flightSuretyData = await FlightSuretyData.new(firstAirline, "VNAIRLINE");
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);


    return {
        owner: owner,
        firstAirline: firstAirline,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

module.exports = {
    Config: Config
};