// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.9.0;

contract FlightSuretyApp {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    IFlightSuretyData flightSuretyData;

    bool private operational = true; // Blocks all state changes throughout the contract if false
    address private contractOwner; // Account used to deploy contract

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

    mapping(address => address[]) public pendingAirlines;

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address contractData) {
        contractOwner = msg.sender;
        flightSuretyData = IFlightSuretyData(contractData);
    }

    /********************************************************************************************/
    /*                                            EVENTS                                        */
    /********************************************************************************************/

    event DebuggerEvent(
        address airline,
        uint256 number,
        string str,
        bytes32 b32
    );
    event RegisterAirline(address airline, uint256 voted);
    event RegisterFlight(bytes32 flightKey);

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
        (bool isRegistered, ) = flightSuretyData.getAirlineInfo(airline);
        require(!isRegistered, "Airline was already registered.");
        _;
    }

    modifier requireAirlineFunded(address airline) {
        (, uint256 fundAmount) = flightSuretyData.getAirlineInfo(airline);
        require(
            fundAmount >= AIRLINE_REGISTRATION_FEE,
            "Airline was not funded."
        );
        _;
    }

    modifier requireAirlineRegistered(address airline) {
        (bool isRegistered, ) = flightSuretyData.getAirlineInfo(airline);
        require(isRegistered, "Airline was not registered.");
        _;
    }

    modifier requireFlightRegistered(bytes32 flightKey) {
        (
            string memory flightNumber,
            uint256 timestamp,
            address airline,
            bool isRegistered,
            uint8 statusCode
        ) = flightSuretyData.getFlightInfo(flightKey);
        require(isRegistered, "Flight was not registered.");
        _;
    }
    modifier requireFlightInUnknownStatus(bytes32 flightKey) {
        (
            string memory flightNumber,
            uint256 timestamp,
            address airline,
            bool isRegistered,
            uint8 statusCode
        ) = flightSuretyData.getFlightInfo(flightKey);
        require(
            statusCode == STATUS_CODE_UNKNOWN,
            "Flight is not in correct state."
        );
        _;
    }
    modifier requireNotBuyInsuranceYet(bytes32 flightKey, address passenger) {
        (uint256 amount, ) = flightSuretyData.getFundedInsuranceAmount(
            flightKey,
            passenger
        );

        require(amount == 0, "Passenger already bought insurance");
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

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function registerAirline(address airline, string memory name)
        external
        requireIsOperational
        requireAirlineNotRegistered(airline)
        requireAirlineFunded(msg.sender)
    {
        uint256 voted = 0;
        if (
            flightSuretyData.getActivatedAirlines().length <
            AIRLINE_VOTING_THRESHOLD
        ) {
            flightSuretyData.registerAirline(airline, name);
        } else {
            bool exiting = false;
            for (uint256 i = 0; i < pendingAirlines[airline].length; i++) {
                if (pendingAirlines[airline][i] == msg.sender) {
                    exiting = true;
                    break;
                }
            }
            require(!exiting, "You already voted for this airline");
            pendingAirlines[airline].push(msg.sender);
            voted = pendingAirlines[airline].length;
            if (
                pendingAirlines[airline].length >=
                flightSuretyData.getActivatedAirlines().length / 2
            ) {
                flightSuretyData.registerAirline(airline, name);
            }
        }

        emit RegisterAirline(airline, voted);
    }

    function fundAirline()
        external
        payable
        requireIsOperational
        requireAirlineRegistered(msg.sender)
    {
        require(msg.sender.balance >= msg.value, "Not enough Ether to fund");
        payable(address(flightSuretyData)).transfer(msg.value);
        uint256 fundedAmount = flightSuretyData.fundAirline(
            msg.sender,
            msg.value
        );
        if (fundedAmount >= AIRLINE_REGISTRATION_FEE) {
            flightSuretyData.activateAirline(msg.sender);
        }
    }

    function registerFlight(string calldata flightNumber, uint256 timestamp)
        external
        requireIsOperational
        requireAirlineFunded(msg.sender)
    {
        bytes32 key = getFlightKey(msg.sender, flightNumber, timestamp);
        flightSuretyData.registerFlight(
            key,
            flightNumber,
            timestamp,
            msg.sender
        );
        emit RegisterFlight(key);
    }

    function buyInsurance(bytes32 flightKey)
        external
        payable
        requireIsOperational
        requireFlightRegistered(flightKey)
        requireFlightInUnknownStatus(flightKey)
    // requireNotBuyInsuranceYet(flightKey, msg.sender)
    {
        (uint256 amount, ) = flightSuretyData.getFundedInsuranceAmount(
            flightKey,
            msg.sender
        );

        require(msg.sender.balance >= msg.value, "Not enough Ether to fund");
        require(msg.value <= ISSURANCE_MAX, "Maxinum 1 ether for insurance");
        payable(address(flightSuretyData)).transfer(msg.value);
        flightSuretyData.buyInsurance(flightKey, msg.value, msg.sender);
    }

    function getActivatedAirlines()
        external
        view
        requireIsOperational
        returns (address[] memory airlines)
    {
        return flightSuretyData.getActivatedAirlines();
    }

    function getAirlineAddresses()
        external
        view
        requireIsOperational
        returns (address[] memory airlineAddresses)
    {
        return flightSuretyData.getAirlineAddresses();
    }

    function getFlightKeys()
        external
        view
        requireIsOperational
        returns (bytes32[] memory flightKeys)
    {
        return flightSuretyData.getFlightKeys();
    }

    function getFundByAirline(address add)
        public
        view
        requireIsOperational
        returns (uint256 amount)
    {
        (, uint256 fundAmount) = flightSuretyData.getAirlineInfo(add);
        return fundAmount;
    }

    function getAirlineInfo(address add)
        public
        view
        requireIsOperational
        returns (bool isRegistered, uint256 amount)
    {
        return flightSuretyData.getAirlineInfo(add);
    }

    function getFlightInfo(bytes32 key)
        public
        view
        requireIsOperational
        returns (
            string memory flightNumber,
            uint256 timestamp,
            address airline,
            bool isRegistered,
            uint8 statusCode
        )
    {
        return flightSuretyData.getFlightInfo(key);
    }

    function getFundedInsuranceAmount(bytes32 flightKey, address passenger)
        public
        view
        requireIsOperational
        returns (uint256 amount, uint256 claimAmount)
    {
        return flightSuretyData.getFundedInsuranceAmount(flightKey, passenger);
    }

    function withdraw() external requireIsOperational {
        flightSuretyData.withdraw(payable(msg.sender));
    }

    function getWithdrawableInsurance() external requireIsOperational {
        flightSuretyData.getWithdrawableAmount(msg.sender);
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
    ) internal {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        (, , , , uint8 sc) = flightSuretyData.getFlightInfo(flightKey);
        if (sc == 0) {
            flightSuretyData.updateFlight(flightKey, statusCode);
            if (statusCode == 20) {
                flightSuretyData.claimInsurance(flightKey);
            }
        }
    }

    function fetchFlightStatus(bytes32 flightKey) external {
        (
            string memory flightNumber,
            uint256 timestamp,
            address airline,
            ,

        ) = flightSuretyData.getFlightInfo(flightKey);
        _fetchFlightStatus(airline, flightNumber, timestamp);
    }

    // Generate a request for oracles to fetch flight information
    function _fetchFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp
    ) private {
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

    /********************************************************************************************/
    /*                                     ORACLE MANAGEMENT                                    */
    /********************************************************************************************/
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

        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;
    mapping(bytes32 => mapping(uint8 => address[])) oracleResponseResults; // Mapping key is the status code reported)

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
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
        string calldata flight,
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

        // oracleResponses[key].responses[statusCode].push(msg.sender);
        oracleResponseResults[key][statusCode].push(msg.sender);
        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponseResults[key][statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        returns (uint8[3] memory)
    {
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

interface IFlightSuretyData {
    function registerAirline(address airline, string memory name) external;

    function fundAirline(address airlineAddress, uint256 amount)
        external
        returns (uint256 fundedAmount);

    function registerFlight(
        bytes32 flightKey,
        string memory flightNumber,
        uint256 timestamp,
        address airline
    ) external;

    function updateFlight(bytes32 flightKey, uint8 statusCode) external;

    function claimInsurance(bytes32 flightKey) external;

    function buyInsurance(
        bytes32 flightKey,
        uint256 amount,
        address buyer
    ) external payable;

    function getAirlineAddresses() external view returns (address[] memory);

    function getAirlineInfo(address ad)
        external
        view
        returns (bool isRegistered, uint256 fundAmount);

    function getFlightKeys() external view returns (bytes32[] memory);

    function getFlightInfo(bytes32 key)
        external
        view
        returns (
            string memory flightNumber,
            uint256 timestamp,
            address airline,
            bool isRegistered,
            uint8 statusCode
        );

    function getFundedInsuranceAmount(bytes32 flightKey, address passenger)
        external
        view
        returns (uint256 amount, uint256 claimAmount);

    function withdraw(address payable payoutAddress) external;

    function getWithdrawableAmount(address passenger) external;

    function activateAirline(address airline) external;

    function getActivatedAirlines()
        external
        view
        returns (address[] memory airlines);
}
