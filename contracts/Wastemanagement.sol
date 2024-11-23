// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./libraries/Wastelibrary.sol";
import {IEscrow} from "./IEscrow.sol";

  contract WasteManagement {
    IEscrow public escrowContract; // Address of the Escrow contract

    constructor(address _escrowContract) {
        escrowContract = IEscrow(_escrowContract);
    }

    uint256 numberOfUsers;

    struct Coordinates {
        int32 latitude;
        int32 longitude;
    }

    struct User {
        uint256 id;
        address userAddress;
        Coordinates location;
        bool isRegistered;
    }

    event RequestCreated(
        uint256 requestID,
        address userAddress,
        address recyclerAddress,
        uint256 offerId,
        uint256 weight,
        uint256 priceAgreed
    );
    event RequestAccepted(uint256 requestID, address collectorAddress);
    event RequestConfirmed(uint256 requestID, address collectorAddress);
    event CollectionRequestCanceled(uint requestID);
    event NewUserJoined(address userAddress, int32 latitude, int32 longitude);
    
    mapping(address => User) public users;

     /** 
     * @notice Creates a new user.
     * @dev accessible only to an unregistered user.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function _createUser(address _user) internal {
        User storage user = users[_user];
        
        if (user.isRegistered) revert waste.REGISTERED();
        
        user.id = ++numberOfUsers; // Increment and assign ID
        user.userAddress = _user; 
        user.isRegistered = true; 
    }

    /** 
     * @notice Sets the user's location.
     * @param _latitude The latitude of the user's location.
     * @param _longitude The longitude of the user's location.
     * @dev accessible only to registered users.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function _setUserLocation(address _user, int32 _latitude, int32 _longitude) internal {
        if (!users[_user].isRegistered) revert waste.NOT_REGISTERED();
        
        users[_user].location = Coordinates(_latitude, _longitude);
    }

    // function getUser(address _userAddress) external view returns ( uint256 id,address userAddress,  string memory location, bool isRegistered ){

    //     User storage user = users[_userAddress];

    //     return (  user.id , user.userAddress , user.location , user.isRegistered );
    // }

    /************************************************************************************************************************************************************************************/

    uint256 public numberOfRecyclers;

    struct Recycler {
        uint256 id;
        address recyclerAddress;
        string location;
        uint256 rating;
        bool isRegistered;
        //bool isActive;
    }

    struct Offer {
        uint256 offerId;
        string name;
        address recyclerAddress;
        uint256 pricePerKg;
        uint256 minQuantity;
    }

    mapping(address => Offer[]) public recyclerOffer; //RecylcerAddress => Offer

    mapping(address => Recycler) public recyclers;

    address[] recyclersAddresses;

    mapping(address => Coordinates) public recyclerCordinate;

    event RecyclerCreated(
        address indexed _recyclerAddress,
        string _location,
        int32 lat,
        int32 lon
    );

    event OfferCreated(
        address indexed recycler,
        string _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    );

    function createRecycler(
        address _recyclerAddress,
        string memory _location,
        int32 lat,
        int32 lon
    ) external {
        if (recyclers[_recyclerAddress].isRegistered == true)
            revert waste.RECYCLER_ALREADY_REGISTERED();

        if (lat == 0) revert waste.INVALIDLATITUTUDE();
        if (lon == 0) revert waste.INVALIDLONGITUDE();

        uint256 _id = numberOfRecyclers + 1;

        Recycler storage recycler = recyclers[_recyclerAddress];

        recycler.id = _id;
        recycler.recyclerAddress = _recyclerAddress;
        recycler.location = _location;
        recycler.isRegistered = true;
        recyclersAddresses.push(_recyclerAddress);

        Coordinates storage cord = recyclerCordinate[_recyclerAddress];
        cord.latitude = lat;
        cord.longitude = lon;

        numberOfRecyclers++;

        emit RecyclerCreated(_recyclerAddress, _location, lat, lon);
    }

    function seeAllRecyclers() external view returns (address[] memory) {
        return recyclersAddresses;
    }

    function createOffer(
        string memory _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    ) external {
        if (!recyclers[msg.sender].isRegistered) revert waste.INVALIDRECYCLER();
        if (bytes(_wasteType).length < 3) revert waste.INVALIDOFFERNAME();
        if (_pricePerKg <= 0) revert waste.INVALIDPRICE();
        if (_miniQuantity == 0) revert waste.INVALIDQUANTITY();
        uint256 offerId = recyclerOffer[msg.sender].length;
        recyclerOffer[msg.sender].push(
            Offer({
                offerId: offerId + 1,
                name: _wasteType,
                recyclerAddress: msg.sender,
                pricePerKg: _pricePerKg,
                minQuantity: _miniQuantity
            })
        );

        emit OfferCreated(msg.sender, _wasteType, _pricePerKg, _miniQuantity);
    }

    function viewOffer(address _recyclerAddress, uint256 _offerId) external view returns (Offer memory) {
        if (!recyclers[_recyclerAddress].isRegistered) revert waste.INVALIDRECYCLER();

        if (recyclerOffer[_recyclerAddress][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        return recyclerOffer[_recyclerAddress][_offerId];
    }

    function updateOffer(
        uint256 _offerId,
        string memory _name,
        address _recyclerAddress,
        uint256 _pricePerKg,
        uint256 _minQuantity
    ) external returns (Offer memory) {
        if (!recyclers[msg.sender].isRegistered) revert waste.INVALIDRECYCLER();

        if (recyclerOffer[msg.sender][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        Offer storage offer = recyclerOffer[msg.sender][_offerId];
        offer.name = _name;
        offer.recyclerAddress = _recyclerAddress;
        offer.pricePerKg = _pricePerKg;
        offer.minQuantity = _minQuantity;

        return offer;
    }
    /************************************************************************************************************************************************************************************/

    uint256 public numOfCollector;


   
    struct Collector {
        uint256 id;
        string name;
        address collectorAddress;
        string contact;
        uint256 numberOfWasteCollected;
        bool isAvailable;
    }

    struct CollectorInfo {
        uint256 id;
        string name;
        address collectorAddress;
        string contact;
        uint256 numberOfWasteCollected;
        bool isAvailable;
        address recyclerAddress;
    }

    mapping(address => mapping(address => Collector)) internal  collectors; //RecyclerAddress => Collector Address => Collection.

    mapping(address => address[]) private recyclerCollectors; // recycler address => array of collector addresses

    function createCollector(address _collectorAddress,string memory _name, string memory _contact ) external {
        //should be set by recyclers/

        Recycler storage recycler = recyclers[msg.sender];

        if (recycler.recyclerAddress != msg.sender)
            revert waste.NOT_AUTHORIZED();

        uint256 _id = numOfCollector + 1;

        Collector storage collector = collectors[msg.sender][_collectorAddress];

        collector.id = _id;
        collector.name = _name;
        collector.collectorAddress = _collectorAddress;
        collector.contact = _contact;
        collector.numberOfWasteCollected = 0;
        collector.isAvailable = true;

        // Add collector to recycler's collectors list 
        bool exists = false;
        for (uint i = 0; i < recyclerCollectors[msg.sender].length; i++) {
            if (recyclerCollectors[msg.sender][i] == _collectorAddress) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            recyclerCollectors[msg.sender].push(_collectorAddress);
        }
                                                
        numOfCollector++;
    }


      // New function to get all collectors for a specific recycler
    function getRecyclerCollectors(address _recyclerAddress) 
        external 
        view 
        returns (address[] memory) 
    {
        if (!recyclers[_recyclerAddress].isRegistered) revert waste.RECYCLERNOTFOUND();
        
        return recyclerCollectors[_recyclerAddress];
    }                                                              
    

    //Get detailed information about all collectors for a recycler

    function getRecyclerCollectorsDetails(address _recyclerAddress)
        external
        view
        returns (CollectorInfo[] memory)
    {
        if (!recyclers[_recyclerAddress].isRegistered) revert waste.RECYCLERNOTFOUND();
        
        address[] memory collectorAddresses = recyclerCollectors[_recyclerAddress];
        CollectorInfo[] memory collectorsInfo = new CollectorInfo[](collectorAddresses.length);
        
        for (uint i = 0; i < collectorAddresses.length; i++) {
            address collectorAddr = collectorAddresses[i];
            Collector storage collector = collectors[_recyclerAddress][collectorAddr];
            
            collectorsInfo[i] = CollectorInfo({
                id: collector.id,
                name: collector.name,
                collectorAddress: collector.collectorAddress,
                contact: collector.contact,
                numberOfWasteCollected: collector.numberOfWasteCollected,
                isAvailable: collector.isAvailable,
                recyclerAddress: _recyclerAddress
            });
        }
        
        return collectorsInfo;
    }

    uint256 public numOfRequest;

    enum RequestStatus {
        PENDING,
        ACCEPTED,
        COMPLETED,
        CANCELLED
    }

    struct WasteCollectionRequest {
        uint256 id;
        address userAddress;
        address recyclerAddress;
        uint256 offerId;
        uint256 weight;
        uint256 valuedAt;
        uint256 amountPaid; // Payment amount in tokens
        bool isCompleted;
        bool isAccepted; // to track if the request is accepted
        address assignedCollector; // Collector who accepted the request
        uint256 escrowRequestID; // Reference to the escrow contract request ID
        RequestStatus status;
    }

    mapping(uint256 => WasteCollectionRequest) public userWasteRequests;
    //mapping to track collector requests
    mapping(address => uint256[]) private collectorRequests; // collector address => array of request IDs

    event RequestCancelled(uint _requestId);

    //should be called by users
    function makeRequest(
        address _recyclerAddress,
        uint256 _offerId,
        uint256 _weight,
        uint256 _price,
        int32 _latitude,        
        int32 _longitude
    ) external {
        User memory user = users[msg.sender];
        Recycler storage recycler = recyclers[_recyclerAddress];
        
        // Ensure user and recycler are registered
        if (!user.isRegistered) {
            _createUser(msg.sender);
            _setUserLocation(msg.sender, _latitude, _longitude);
            emit NewUserJoined(msg.sender, _latitude, _longitude);
        }

        if (!recycler.isRegistered) revert waste.RECYCLERNOTFOUND();


        if (_price < 0) revert waste.INVALIDAMOUNT();

        // Check if the recycler offers the specified waste type
        if (recyclerOffer[_recyclerAddress][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        Offer memory offer = recyclerOffer[_recyclerAddress][_offerId];

        if (_weight < offer.minQuantity) revert waste.LOWER_THAN_MINQUANTITY();

        uint256 _requestID = numOfRequest + 1;

        WasteCollectionRequest storage req = userWasteRequests[_requestID];

        req.id = _requestID;
        req.userAddress = msg.sender;
        req.recyclerAddress = _recyclerAddress;
        req.offerId = _offerId;
        req.weight = _weight;
        req.valuedAt = _price;

        numOfRequest++;

        emit RequestCreated(
            _requestID,
            msg.sender,
            _recyclerAddress,
            _offerId,
            _weight,
            _price
        );
    }

    function showRequest(
        uint256 _requestID
    ) external view returns (WasteCollectionRequest memory) {
        if (userWasteRequests[_requestID].id == 0)
            revert waste.REQUESTNOTFOUND();
        return userWasteRequests[_requestID];
    }

    function acceptRequest(
        uint256 _requestID,
        address _collectorAddress
    ) external payable {
        //should be called by the recycler

        Collector storage collector = collectors[msg.sender][_collectorAddress];
        WasteCollectionRequest storage req = userWasteRequests[_requestID];

        if (req.recyclerAddress != msg.sender) revert waste.ONLY_A_RECYCLER();

        if (req.isAccepted) revert waste.ALLREADY_ACCEPTED();

        if (req.isCompleted) revert waste.ALREADY_COMPLETED();
        if (req.assignedCollector != address(0))
            revert waste.REQUESTALREADYASSIGNED();
        
        if (msg.value < req.valuedAt) revert waste.AMOUNT_LESS_THAN_AMOUNT_VALUED();

        // Collector storage collector = collectors[msg.sender][_collectorAddress];

        // Mark request as accepted
        req.isAccepted = true;
        //collection.isCompleted = false;  // Mark as in progress
        req.assignedCollector = _collectorAddress;

        collector.numberOfWasteCollected++;

        // Add request to collector's requests array
        collectorRequests[_collectorAddress].push(_requestID);


        // Create the escrow and then retrieve the current escrow ID from EscrowContract
        uint256 escrowId = escrowContract.createEscrow{value: req.valuedAt}(
            req.recyclerAddress
        );

        req.escrowRequestID = escrowId;

        // Emit an event to indicate request acceptance
        emit RequestAccepted(_requestID, _collectorAddress);
    }


    //struct for detailed request information
    struct CollectorRequestDetails {
        uint256 requestId;
        address userAddress;
        address recyclerAddress;
        uint256 offerId;
        uint256 weight;
        uint256 valuedAt;
        RequestStatus status;
        bool isCompleted;
        bool isAccepted;
    }

    // Function to get all request IDs assigned to a collector
    function getCollectorRequestIds(address _collectorAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return collectorRequests[_collectorAddress];
    }


    // Function to get detailed information about all requests assigned to a collector
    function getCollectorRequests(address _collectorAddress)
        external
        view
        returns (CollectorRequestDetails[] memory)
    {
        uint256[] memory requestIds = collectorRequests[_collectorAddress];
        CollectorRequestDetails[] memory requests = new CollectorRequestDetails[](requestIds.length);

        for (uint256 i = 0; i < requestIds.length; i++) {
            WasteCollectionRequest storage request = userWasteRequests[requestIds[i]];
            
            requests[i] = CollectorRequestDetails({
                requestId: request.id,
                userAddress: request.userAddress,
                recyclerAddress: request.recyclerAddress,
                offerId: request.offerId,
                weight: request.weight,
                valuedAt: request.valuedAt,
                status: request.status,
                isCompleted: request.isCompleted,
                isAccepted: request.isAccepted
            });
        }

        return requests;
    }

    // should be called by the collector
    function confirmRequest(uint256 _requestID) external {
        WasteCollectionRequest storage req = userWasteRequests[_requestID];

        // Ensure the request is accepted and not already completed
        if (req.assignedCollector != msg.sender) revert waste.NOT_ASSIGNED();

        if (!req.isAccepted) revert waste.NOT_ACCEPTED_YET();

        if (req.isCompleted) revert waste.ALREADY_COMPLETED();

        // Mark the request as completed
        req.isCompleted = true;

        escrowContract.releaseEscrow(req.escrowRequestID);

        // Set the collector's availability back to true
        // Collector storage collector = collectors[msg.sender][req.assignedCollector];
        // collector.isAvailable = true;

        // Emit an event indicating the completion of the request
        emit RequestConfirmed(_requestID, msg.sender);
    }

    function userCancelRequest(uint256 _requestID) external {
        WasteCollectionRequest storage req = userWasteRequests[_requestID];

        if (req.id == 0) revert waste.REQUESTNOTFOUND();

        if (req.userAddress != msg.sender) revert waste.NOT_AUTHORIZED();

        if (req.isCompleted) revert waste.ALREADY_COMPLETED();

        if (req.isAccepted) {
            // escrowContract.refundEscrow(req.escrowRequestID);
            revert waste.ALREADY_ACCEPTED();
        }

        req.status = RequestStatus.CANCELLED;

        emit RequestCancelled(_requestID);
    }

    function cancelRequestAndRefund(uint256 _requestID) external {
        WasteCollectionRequest storage req = userWasteRequests[_requestID];

        // Ensure the request isn't completed
        if (req.isCompleted) revert waste.ALREADY_COMPLETED();

        // Ensure only the recycler or the collector can cancel the request
        if (
            msg.sender != req.recyclerAddress &&
            msg.sender != req.assignedCollector
        ) revert waste.NOT_AUTHORIZED();

        // Trigger the refundEscrow function in the Escrow contract
        escrowContract.refundEscrow(req.escrowRequestID);

        // Mark the request as canceled to prevent future actions on it
        req.isCompleted = true;

        emit CollectionRequestCanceled(_requestID);
    }


    function getUserRole(address _userAddress) external view returns (
    string memory role,
    uint256 id,
    address addr,
    int32 latitude,
    int32 longitude,
    string memory location,
    bool isRegistered
    ) {
    // Check if the address is a user
    if (users[_userAddress].isRegistered) {
        User storage user = users[_userAddress];
        return (
            "User",
            user.id,
            user.userAddress,
            user.location.latitude,
            user.location.longitude,
            "",
            user.isRegistered
        );
    }

    // Check if the address is a recycler
    if (recyclers[_userAddress].isRegistered) {
        Recycler storage recycler = recyclers[_userAddress];
        Coordinates storage coord = recyclerCordinate[_userAddress];
        return (
            "Recycler",
            recycler.id,
            recycler.recyclerAddress,
            coord.latitude,
            coord.longitude,
            recycler.location,
            recycler.isRegistered
        );
    }

    // Check if the address is a collector
    for (uint256 i = 0; i < recyclersAddresses.length; i++) {
        address recyclerAddr = recyclersAddresses[i];
        if (collectors[recyclerAddr][_userAddress].collectorAddress != address(0)) {
            Collector storage collector = collectors[recyclerAddr][_userAddress];
            return (
                "Collector",
                collector.id,
                collector.collectorAddress,
                0,
                0,
                "",
                collector.isAvailable
            );
        }
    }

    // If no match is found, revert
    revert waste.NOT_FOUND();
}



}

