pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    address[] private registeredAirlines;
    address[] private fundedAirlines;    
    bytes32[] flightKeys;
    mapping(address => Airline) private mRegisteredAirlines;
    mapping(address => bool) private authorizedAppContracts;
    mapping(bytes32 => Insurance[]) private flightInsurances;
    mapping(bytes32 => Flight) private flights;

    /********************************************************************************************/
    /*                                      STRUCT DEFINITION                                   */
    /********************************************************************************************/

    struct Airline {
        bool isRegistered;
        uint256 fundAmount;
    }

    struct Insurance {
        address passenger;        
        uint256 amount;
    }

    struct Flight {
        bytes32 flightNumber;        
        uint256 timestamp;
        address airline;
        bool sIsRegistered;
        uint8 statusCode;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address firstAirline) public {
        contractOwner = msg.sender;
        //register first airline
        _registerAirline(firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAirlineNotRegistered(address airline) {
        require(
            !mRegisteredAirlines[airline].isRegistered,
            "Airline was registered"
        );
        _;
    }

    modifier requireAirlineRegistered(address airline) {
        require(
            mRegisteredAirlines[airline].isRegistered,
            "Airline was not registered"
        );
        _;
    }

    modifier requireAirlineFunded(address airline) {
        require(
            mRegisteredAirlines[airline].fundAmount > 0,
            "Airline was not funded"
        );
        _;
    }

    modifier requireAuthorizedCaller() {
        // require(authorizedAppContracts[msg.sender], "App contract is not authorized");
        _;
    }
    
    modifier requireFlightKeyNotRegistered(bytes32 flightKey) {
        require(!flights[flightKey].sIsRegistered, "Flight is already registered.");
        _;
    }
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }
    function authorizeCaller(address appContract) public {
        authorizedAppContracts[appContract] = true;
    }
    function getFundedAirlines() external view returns(address[] airlines){
        return fundedAirlines;
    }
    function getRegisteredAirline() external view returns(address[] addresses){
        return registeredAirlines;
    }
    function isAirlineRegistered(address airline) external view returns(bool isRegistered){
        return mRegisteredAirlines[airline].isRegistered;
    }
    function getFundByAirline(address airline) external view returns(uint256 amount){
        return mRegisteredAirlines[airline].fundAmount;
    }
    function getFlightByKey(bytes32 flightKey) external view returns(
        bytes32 flightNumber,        
        uint256 timestamp,
        address airline,        
        uint8 statusCode){
        Flight memory foundFlight = flights[flightKey];
        return (foundFlight.flightNumber, foundFlight.timestamp, foundFlight.airline, foundFlight.statusCode);
    }
    function getFlightKeys() external view returns(bytes32[] keys){
        return flightKeys;        
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function setAuthorizationContractStatus(
        address _appContract,
        bool isAuthorized
    ) external requireContractOwner {
        authorizedAppContracts[_appContract] = isAuthorized;
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address airline, address fundedAirline)
        external
        requireIsOperational
        requireAuthorizedCaller
        requireAirlineNotRegistered(airline)
        requireAirlineFunded(fundedAirline)
    {
        _registerAirline(airline);
    }

    function _registerAirline(address airline) internal requireIsOperational {
        mRegisteredAirlines[airline] = Airline(true, 0);
        registeredAirlines.push(airline);
    }
// requireFlightKeyNotRegistered(flightKey) 
    function registerFlight(bytes32 flightKey, uint256 timestamp,
        address airline,
        bytes32 flightNumber) external requireIsOperational requireAuthorizedCaller        
        {
            
        flights[flightKey] = Flight(flightNumber, timestamp, airline, true, uint8(0));

        flightKeys.push(flightKey);
    }

    /**
     * @dev Fund to finish registering airline
     *
     */
    function fundAirline(address airlineAddress, uint256 amount)
        external
        requireIsOperational
        requireAuthorizedCaller
        requireAirlineRegistered(airlineAddress)
    {        
        mRegisteredAirlines[airlineAddress].fundAmount = mRegisteredAirlines[airlineAddress].fundAmount.add(amount);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buyInsurance(bytes32 flightKey, address passenger, uint256 amount) external requireIsOperational requireAuthorizedCaller{
         flightInsurances[flightKey].push(Insurance(passenger, amount));
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        fund();
    }
}
