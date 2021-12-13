pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData private flightSuretyData;

    bool private operational = true; // Blocks all state changes throughout the contract if false

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private AIRLINE_VOTING_THRESHOLD = 4;
    uint256 AIRLINE_REGISTRATION_FEE = 10 ether;
    uint256 ISSURANCE_MAX = 1 ether;

    address private contractOwner; // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    struct Vote {
        uint256 votedCount;
        mapping(address => bool) voted;
    }

    mapping(bytes32 => Flight) private flights;
    mapping(address => Vote) private waitingForVotedAirlines;

    /********************************************************************************************/
    /*                                            EVENTS                                        */
    /********************************************************************************************/

    event DebuggerEvent(address airline, uint256 number, string str, bytes32 b32);
    event FlightRegistered(
        string flightKey,
        string flightNumber,
        address airline,
        uint256 timestamp
    );
    event AirlineRegistered(address airline);
    event AirlineFunded(address airline, uint256 amount);
    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleRegistered(address oracle);

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

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
        // Modify to call data contract's status
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
            !flightSuretyData.isAirlineRegistered(airline),
            "Airline was registered"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireAirlineRegistered(address airline) {
        require(
            flightSuretyData.isAirlineRegistered(airline),
            "Airline was not registered"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }
    modifier requireAirlineRegisteredOverThreshold(address airline) {
        require(
            waitingForVotedAirlines[airline].votedCount >=
                waitingForVotedAirlines[airline].votedCount.div(2),
            "Airline is under threshold"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireRegistedAirlineIsFunded(address airline) {
        require(
            flightSuretyData.getFundByAirline(airline) >=
                AIRLINE_REGISTRATION_FEE,
            "Airline was not funded enough"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireMaxIssuranceLimit() {
        require(
            msg.value <= ISSURANCE_MAX,
            "Maximum 1 ether for buying insurance"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address contractData) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(contractData);
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

    function getRegisteredAirlineAddresses()
        public
        view
        returns (address[] addresses)
    {
        return flightSuretyData.getRegisteredAirline();
    }

    function getFundByAirline(address add)
        public
        view
        returns (uint256 amount)
    {
        return flightSuretyData.getFundByAirline(add);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address airline)
        external
        requireIsOperational
        requireAirlineNotRegistered(airline)
        returns (
            // requireRegistedAirlineIsFunded
            bool success,
            uint256 votes
        )
    {
        // emit DebuggerEvent(airline,uint(0));
        // emit DebuggerEvent(msg.sender,uint(0));
        // emit DebuggerEvent(airline,flightSuretyData.getFundByAirline(msg.sender));
        emit AirlineRegistered(airline);
        // emit DebuggerEvent(airline,uint(0));
        //the number of airlines is below the threshold
        if (
            flightSuretyData.getFundedAirlines().length <
            AIRLINE_VOTING_THRESHOLD
        ) {
            flightSuretyData.registerAirline(airline, msg.sender);
            return (true, 0);
        } else {
            // handle airline registration in contract app for voting
            Vote storage al = waitingForVotedAirlines[airline];
            require(
                !waitingForVotedAirlines[airline].voted[msg.sender],
                "You were already registered this airline"
            );
            al.votedCount = al.votedCount.add(1);
            if (al.votedCount < al.votedCount.div(2)) {
                al.voted[msg.sender] = true;
            } else {
                flightSuretyData.registerAirline(airline, msg.sender);
            }

            delete waitingForVotedAirlines[airline];

            return (true, al.votedCount);
        }
    }

    function fundAirline()
        external
        payable
        requireIsOperational
        requireAirlineRegistered(msg.sender)
    {
        require(msg.value >= AIRLINE_REGISTRATION_FEE, "Minimum 10 Ether");
        require(msg.sender.balance > msg.value, "Not enough Ether to fund");
        address(flightSuretyData).transfer(msg.value);
        flightSuretyData.fundAirline(msg.sender, msg.value);

        emit AirlineFunded(msg.sender, msg.value);
    }

    function buyIssurance(bytes32 flight)
        external
        payable
        requireIsOperational
        requireMaxIssuranceLimit
    {
        address(flightSuretyData).transfer(msg.value);
        flightSuretyData.buyInsurance(flight, msg.sender, msg.value);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(bytes32 flightNumber, uint256 timestamp)
        external
        // requireIsOperational
    // requireRegistedAirlineIsFunded(msg.sender)
    {        
        bytes32 flightKey = getFlightKey(msg.sender, flightNumber, timestamp);        
        emit DebuggerEvent(msg.sender, timestamp, '', flightKey);
        flightSuretyData.registerFlight(
            flightKey,
            timestamp,
            msg.sender,
            flightNumber
        );
    }
    // function registerFlight(
    //     bytes32 flightKey,
    //     uint256 timestamp,
    //     address airline,
    //     bytes32 flightNumber
    // ) external;
    function getFlightByKey(bytes32 flightKey)
        external
        view
        requireIsOperational
        returns (
            string flightNumber,
            uint256 timestamp,
            address airline,
            uint8 statusCode
        )
    {
        return flightSuretyData.getFlightByKey(flightKey);
    }

    function getFlightKeys()
        external
        view
        requireIsOperational
        returns (bytes32[] flightKeys)
    {
        return flightSuretyData.getFlightKeys();
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal pure {}

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3]) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        bytes32 flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

contract FlightSuretyData {
    function getFundedAirlines() external view returns (address[] airlines);

    function getRegisteredAirline() external view returns (address[] addresses);

    function fundAirline(address airlineAddress, uint256 amount) external;

    function getFundByAirline(address airline)
        external
        view
        returns (uint256 amount);

    function isAirlineRegistered(address airline)
        external
        view
        returns (bool isRegistered);

    function registerAirline(address airline, address fundedAirline) external;

    function registerFlight(
        bytes32 flightKey,
        uint256 timestamp,
        address airline,
        bytes32 flightNumber
    ) external;

    function getFlightByKey(bytes32 flightKey)
        external
        view
        returns (
            string flightNumber,
            uint256 timestamp,
            address airline,
            uint8 statusCode
        );

    function getFlightKeys() external view returns (bytes32[] flightKeys);

    function buyInsurance(
        bytes32 flightKey,
        address passenger,
        uint256 amount
    ) external;
}
