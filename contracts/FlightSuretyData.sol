// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.9.0;

contract FlightSuretyData {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    address public latestAuthorizedCaller; // Account used to deploy contract
    mapping(address => bool) private authorizedAppContracts;

    mapping(address => Airline) private registeredAirlines;
    mapping(bytes32 => Flight) private registeredFlights;
    mapping(bytes32 => Insurance[]) private boughtInsurances;
    mapping(address => uint256) private withdrawableFunds;

    address[] private airlineAddresses;
    address[] private activatedAirlineAddresses;
    bytes32[] private flightKeys;

    /********************************************************************************************/
    /*                                      STRUCT DEFINITION                                   */
    /********************************************************************************************/

    struct Airline {
        bool isRegistered;
        string name;
        uint256 fundAmount;
    }

    struct Insurance {
        address passenger;
        uint256 amount;
        uint256 claimAmount;
    }

    struct Flight {
        string flightNumber;
        uint256 timestamp;
        address airline;
        bool isRegistered;
        uint8 statusCode;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address firstAirline, string memory firstAirlineName) {
        contractOwner = msg.sender;        
        _registerAirline(firstAirline, firstAirlineName);
        _initFlight(firstAirline);
    }

    function _initFlight(address firstAirline) internal {
        for (uint8 i = 0; i < 5; i++) {
            string memory flightName = "TVP_INIT";
            uint timestamp = block.timestamp + i;
            bytes32 flightKey = keccak256(
                abi.encodePacked(firstAirline, flightName, timestamp)
            );
            _registerFlight(flightKey, flightName, timestamp, firstAirline);
        }
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

    modifier requireAuthorizedCaller() {        
        require(
            authorizedAppContracts[msg.sender],
            "App contract is not authorized"
        );
        
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

    function isAppContractAuthorized(address appContract) external view requireIsOperational returns (bool) {
        return authorizedAppContracts[appContract];
    }

    function authorizeCaller(address appContract) external requireContractOwner {        
        authorizedAppContracts[appContract] = true;
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
    function registerAirline(address airline, string memory name)
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        _registerAirline(airline, name);
    }

    function _registerAirline(address airline, string memory name) private {        
        registeredAirlines[airline] = Airline(true, name, 0);
        airlineAddresses.push(airline);
    }

    /**
     * @dev Fund to finish registering airline
     *
     */
    function fundAirline(address airlineAddress, uint256 amount)
        external
        requireIsOperational
        requireAuthorizedCaller
        returns (uint256 fundedAmount)
    {        
        registeredAirlines[airlineAddress].fundAmount =
            registeredAirlines[airlineAddress].fundAmount +
            amount;
        return registeredAirlines[airlineAddress].fundAmount;
    }

    function activateAirline(address airline)
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        for (uint256 i = 0; i < activatedAirlineAddresses.length; i++) {
            if (activatedAirlineAddresses[i] == airline) {
                return;
            }
        }
        activatedAirlineAddresses.push(airline);
    }

    function registerFlight(
        bytes32 flightKey,
        string calldata flightNumber,
        uint256 timestamp,
        address airline
    ) external requireIsOperational requireAuthorizedCaller {
        _registerFlight(flightKey, flightNumber, timestamp, airline);
    }

    function _registerFlight(
        bytes32 flightKey,
        string memory flightNumber,
        uint256 timestamp,
        address airline
    ) internal {
        registeredFlights[flightKey] = Flight(
            flightNumber,
            timestamp,
            airline,
            true,
            0
        );
        flightKeys.push(flightKey);
    }

    function buyInsurance(
        bytes32 flightKey,
        uint256 amount,
        address buyer
    ) external payable requireIsOperational requireAuthorizedCaller {
        Insurance[] storage insus = boughtInsurances[flightKey];
        for (uint256 i = 0; i < insus.length; i++) {
            if (insus[i].passenger == buyer) {
                revert("Passenger already bought insurance for this flight");
            }
        }

        insus.push(Insurance(buyer, amount, 0));
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT GETTERS                               */
    /********************************************************************************************/

    function getAirlineAddresses()
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns (address[] memory)
    {
        return airlineAddresses;
    }

    function getAirlineInfo(address ad)
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns (bool isRegistered, uint256 fundAmount)
    {
        return (
            registeredAirlines[ad].isRegistered,
            registeredAirlines[ad].fundAmount
        );
    }

    function getFlightKeys()
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns (bytes32[] memory)
    {
        return flightKeys;
    }

    function getFlightInfo(bytes32 key)
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns (
            string memory flightNumber,
            uint256 timestamp,
            address airline,
            bool isRegistered,
            uint8 statusCode
        )
    {
        return (
            registeredFlights[key].flightNumber,
            registeredFlights[key].timestamp,
            registeredFlights[key].airline,
            registeredFlights[key].isRegistered,
            registeredFlights[key].statusCode
        );
    }

    function getFundedInsuranceAmount(bytes32 flightKey, address passenger)
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns (uint256 amount, uint256 claimAmount)
    {
        Insurance[] memory insus = boughtInsurances[flightKey];
        for (uint256 i = 0; i < insus.length; i++) {
            if (insus[i].passenger == passenger) {
                return (insus[i].amount, insus[i].claimAmount);
            }
        }
        return (0, 0);
    }

    function getActivatedAirlines()
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns (address[] memory airlines)
    {
        return activatedAirlineAddresses;
    }

    function updateFlight(bytes32 flightKey, uint8 statusCode)
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        registeredFlights[flightKey].statusCode = statusCode;
    }

    function claimInsurance(bytes32 flightKey)
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        Insurance[] storage insus = boughtInsurances[flightKey];
        for (uint256 i = 0; i < insus.length; i++) {
            insus[i].claimAmount = (insus[i].amount * 3) / 2;
            withdrawableFunds[insus[i].passenger] += insus[i].claimAmount;
        }
    }

    function getWithdrawableAmount(address passenger)
        external
        requireIsOperational
        requireAuthorizedCaller
        returns (uint256 amount)
    {
        return withdrawableFunds[passenger];
    }

    function withdraw(address payable passenger)
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        uint256 amount = withdrawableFunds[passenger];
        require(
            address(this).balance >= amount,
            "Contract has insufficient funds."
        );
        require(amount > 0, "There are no funds available for withdrawal");
        withdrawableFunds[passenger] = 0;
        payable(passenger).transfer(amount);
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {}

    receive() external payable {}
}
