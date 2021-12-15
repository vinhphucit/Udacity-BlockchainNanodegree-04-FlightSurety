
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const {
    BN,
    expectEvent,
    expectRevert,
} = require('@openzeppelin/test-helpers');

contract('Flight Surety Tests', async (accounts) => {
    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);

    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.methods.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSuretyData.isAppContractAuthorized(config.flightSuretyApp.address);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        await expectRevert(
            config.flightSuretyApp.registerAirline(newAirline, "JETSTARS", { from: config.firstAirline }),
            "App contract is not authorized"
        );

        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address, { from: config.owner });

        await expectRevert(config.flightSuretyApp.registerAirline(newAirline, "JETSTARS", { from: config.firstAirline }),
            "Airline was not funded.");

    });

    it('(airline) can fund itself using fundAirline()', async () => {

        // ARRANGE
        let amount = web3.utils.toWei('20', 'ether');
        // ACT

        await config.flightSuretyApp.fundAirline({ from: config.firstAirline, value: amount });

        let result = await config.flightSuretyApp.getFundByAirline(config.firstAirline);

        // ASSERT
        assert.equal(result.toString(), amount.toString(), "Airline is not funded.");
    });

    it('A registgered airline can register another Airline if numnber of registerd airlines is less than 4', async () => {

        // ARRANGE
        let newAirline = accounts[2];
        let amount = web3.utils.toWei('20', 'ether');
        // ACT        
        let registerAirlineResult = await config.flightSuretyApp.registerAirline(newAirline, "UDA_002", { from: config.firstAirline });
        await expectEvent(registerAirlineResult, "RegisterAirline", {
            airline: newAirline,
            voted: "0"
        });

        await config.flightSuretyApp.fundAirline({ from: newAirline, value: amount });

        let result = await config.flightSuretyApp.getAirlineInfo(newAirline);

        // ASSERT
        assert.equal(result.isRegistered, true, "A registerd airline should be able to register another airline");
    });


    it('Only existing airline may register a new airline until there are at least four airlines registered', async () => {

        // ARRANGE
        let secondAirline = accounts[2];
        let thirdAirline = accounts[3];
        let fourthAirline = accounts[4];
        let fifthAirline = accounts[5];
        // ARRANGE
        let amount = web3.utils.toWei('20', 'ether');
        // ACT

        await expectRevert(
            config.flightSuretyApp.registerAirline(secondAirline, "UDC_002", { from: config.firstAirline }),
            "Airline was already registered."
        );

        await config.flightSuretyApp.registerAirline(thirdAirline, "UDC_003", { from: config.firstAirline });
        await config.flightSuretyApp.registerAirline(fourthAirline, "UDC_004", { from: config.firstAirline });



        // ASSERT
        let thirdAirlineresult = await config.flightSuretyApp.getAirlineInfo(thirdAirline);
        assert.equal(thirdAirlineresult.isRegistered, true, "A 3rd registerd airline should be able to register another airline");
        await config.flightSuretyApp.fundAirline({ from: thirdAirline, value: amount });
        let fourthAirlineresult = await config.flightSuretyApp.getAirlineInfo(fourthAirline);
        assert.equal(fourthAirlineresult.isRegistered, true, "A 4th registerd airline should be able to register another airline");
        await config.flightSuretyApp.fundAirline({ from: fourthAirline, value: amount });

        // // fifth airline can't be registered by single airline
        let fifthRegistrationFirstVote = await config.flightSuretyApp.registerAirline(fifthAirline, "UDC_005", { from: config.firstAirline });

        let fifthAirlineresult1 = await config.flightSuretyApp.getAirlineInfo(fifthAirline);

        assert.equal(fifthAirlineresult1.isRegistered, false, "A 5th registerd airline should not be able to register another airline");
        await expectEvent(fifthRegistrationFirstVote, "RegisterAirline", {
            airline: fifthAirline,
            voted: "1"
        });

        let fifthRegistrationSecondVote = await config.flightSuretyApp.registerAirline(fifthAirline, "UDC_005", { from: secondAirline });

        let fifthAirlineresult2 = await config.flightSuretyApp.getAirlineInfo(fifthAirline);

        assert.equal(fifthAirlineresult2.isRegistered, true, "A 5th registerd airline should be able to be registered after getting over 50% ");
        await expectEvent(fifthRegistrationSecondVote, "RegisterAirline", {
            airline: fifthAirline,
            voted: "2"
        });
    });
    it('Airline can be registered, but does not participate in contract until it submits funding of 10 ether (make sure it is not 10 wei', async () => {
        let fifthAirline = accounts[5];
        // ARRANGE
        let flightNumber = "UDA_006";
        let timestamp = new Date().getTime();
        let amount = web3.utils.toWei('10', 'ether');

        // ACT        
        let failRegister = config.flightSuretyApp.registerFlight(flightNumber, timestamp, { from: fifthAirline });

        await expectRevert(failRegister,
            "Airline was not funded."
        );

        await config.flightSuretyApp.fundAirline({ from: fifthAirline, value: amount });

        let registerFlightResult = await config.flightSuretyApp.registerFlight(flightNumber, timestamp, { from: fifthAirline });

        let flightKey = registerFlightResult.logs[0].args.flightKey;

        let result = await config.flightSuretyApp.getFlightInfo(flightKey);

        // ASSERT
        assert.equal(result.isRegistered, true, "Flight should be register only with funded airline");
    });
});
