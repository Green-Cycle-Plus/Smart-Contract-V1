// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { waste } from './libraries/Wastelibrary.sol';
import { IEscrow } from "./IEscrow.sol";

/**
 * @title WasteManagement
 * @dev This contract manages the interactions between users, recyclers, and collectors in waste management.
 */
contract WasteManagement {
    IEscrow public escrowContract; // Address of the Escrow contract

    uint256 public numberOfUsers;
    uint256 public numberOfRecyclers;
    uint256 public numOfCollector;
    uint256 public numOfRequest;

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

    struct Recycler {
        uint256 id;
        address recyclerAddress;
        string location;
        mapping(string => Offer) offers; // Offers by waste type
        uint256 rating;
        bool isRegistered;
    }

    struct Offer {
        uint256 pricePerKg;
        uint256 minQuantity;
    }

    struct Collector {
        uint256 id;
        address collectorAddress;
        bool isAvailable;
    }

    struct CollectionRequest {
        uint256 id;
        address userAddress;
        address recyclerAddress;
        string wasteType;
        uint256 weight;
        uint256 priceAgreed;
        bool isCompleted;
        bool isAccepted; // to track if the request is accepted
        address assignedCollector; // Collector who accepted the request
        uint256 escrowRequestID; // Reference to the escrow contract request ID
    }

    mapping(address => User) public users;
    mapping(address => Recycler) public recyclers;
    mapping(address => Collector) public collectors;

    mapping(uint256 => CollectionRequest) public collectionRequests;

    event RequestCreated(uint256 requestID, address userAddress, address recyclerAddress, string wasteType, uint256 weight, uint256 priceAgreed);
    event RequestAccepted(uint256 requestID, address collectorAddress);
    event RequestConfirmed(uint256 requestID, address collectorAddress);
    event CollectionRequestCanceled(uint requestID);

    constructor(address _escrowContract) {
        escrowContract = IEscrow(_escrowContract);
    }

    /** 
     * @notice Creates a new user.
     * @dev Only callable by an unregistered user.
     */
    function createUser() external {
        User storage user = users[msg.sender];
        
        if (user.isRegistered) revert waste.REGISTERED();
        
        user.id = ++numberOfUsers; // Increment and assign ID
        user.userAddress = msg.sender; 
        user.isRegistered = true; 
    }

    /** 
     * @notice Sets the user's location.
     * @param latitude The latitude of the user's location.
     * @param longitude The longitude of the user's location.
     * @dev Only callable by registered users.
     */
    function setUserLocation(int32 latitude, int32 longitude) external {
        if (!users[msg.sender].isRegistered) revert waste.NOT_REGISTERED();
        
        users[msg.sender].location = Coordinates(latitude, longitude);
    }

    /** 
     * @notice Creates a new recycler.
     * @param _recyclerAddress The address of the recycler.
     * @param _location The location of the recycler.
     * @param _rating The initial rating of the recycler.
     */
    function createRecycler(address _recyclerAddress, string memory _location, uint256 _rating) external {
        Recycler storage recycler = recyclers[_recyclerAddress];
        
        if (recycler.isRegistered) revert waste.REGISTERED();
        
        recycler.id = ++numberOfRecyclers; // Increment and assign ID
        recycler.recyclerAddress = _recyclerAddress; 
        recycler.location = _location; 
        recycler.rating = _rating; 
        recycler.isRegistered = true; 
    }

    /** 
     * @notice Creates an offer for a specific waste type by a recycler.
     * @param _wasteType The type of waste being offered.
     * @param _pricePerKg The price per kilogram for the offered waste.
     * @param _minQuantity The minimum quantity for the offer.
     */
    function createOffer(string memory _wasteType, uint256 _pricePerKg, uint256 _minQuantity) external {
        Recycler storage recycler = recyclers[msg.sender];
        
        if (!recycler.isRegistered) revert waste.NOT_REGISTERED();
        
        Offer storage offer = recycler.offers[_wasteType];
        
        offer.pricePerKg = _pricePerKg; 
        offer.minQuantity = _minQuantity; 
    }

    /** 
     * @notice Allows a user to make a collection request to a recycler.
     * @param _recyclerAddress The address of the recycler.
     * @param _wasteType The type of waste being requested.
     * @param _weight The weight of the waste being requested.
     * @param _price The price agreed for collection.
     */
    function makeRequest(address _recyclerAddress, string memory _wasteType, uint256 _weight, uint256 _price) external {
        User memory user = users[msg.sender];
        
        if (!user.isRegistered) revert waste.NOT_REGISTERED();
        
        Recycler storage recycler = recyclers[_recyclerAddress];
        
        if (!recycler.isRegistered) revert waste.NOT_REGISTERED();
        
        Offer memory offer = recycler.offers[_wasteType];
        
        if (offer.pricePerKg == 0) revert waste.NOT_AMONG_OFFERS();
        
        if (_weight < offer.minQuantity) revert waste.LOWER_THAN_MINQUANTITY();

        CollectionRequest storage collection = collectionRequests[++numOfRequest]; // Increment and assign ID
       
       collection.id = numOfRequest; 
       collection.userAddress = msg.sender; 
       collection.recyclerAddress = _recyclerAddress; 
       collection.wasteType = _wasteType; 
       collection.weight = _weight; 
       collection.priceAgreed = _price; 
       collection.isAccepted = false; 
       collection.isCompleted = false;

       emit RequestCreated(numOfRequest, msg.sender, _recyclerAddress, _wasteType, _weight, _price);
   }

   /** 
   * @notice Allows a recycler to accept a user's collection request.
   * @param _requestID The ID of the collection request being accepted.
   * @param _collectorAddress The address of the collector accepting the request.
   */
   function acceptRequest(uint256 _requestID, address _collectorAddress) external {
       CollectionRequest storage collection = collectionRequests[_requestID];
       
       if (collection.recyclerAddress != msg.sender) revert waste.NOT_AUTHORIZED();
       
       if (collection.isAccepted) revert waste.ALREADY_ACCEPTED();
       
       if (collection.isCompleted) revert waste.ALREADY_COMPLETED();

       collection.isAccepted = true; // Mark as accepted
       collection.assignedCollector = _collectorAddress;

       Collector storage collector = collectors[_collectorAddress];
       
       if (!collector.isAvailable) revert waste.COLLECTOR_NOT_AVAILABLE();

       collector.isAvailable = false; // Mark collector as unavailable

       // Create escrow and retrieve ID
       uint256 escrowId = escrowContract.createEscrow{value: collection.priceAgreed}(collection.userAddress);
       collection.escrowRequestID = escrowId;

       emit RequestAccepted(_requestID, _collectorAddress);
   }

   /** 
   * @notice Confirms that a request has been completed by a collector.
   * @param _requestID The ID of the completed request.
   */
   function confirmRequest(uint256 _requestID) external {
       CollectionRequest storage collection = collectionRequests[_requestID];

       if (collection.assignedCollector != msg.sender) revert waste.NOT_ASSIGNED();
       
       if (!collection.isAccepted) revert waste.NOT_ACCEPTED_YET();
       
       if (collection.isCompleted) revert waste.ALREADY_COMPLETED();

       collection.isCompleted = true;

       escrowContract.releaseEscrow(collection.escrowRequestID);

       Collector storage collector = collectors[msg.sender];
       collector.isAvailable = true; // Set collector's availability back to true

       emit RequestConfirmed(_requestID, msg.sender);
   }

   /** 
   * @notice Cancels a request and triggers a refund for it.
   * @param _requestID The ID of the request to be canceled.
   */
   function cancelRequestAndRefund(uint256 _requestID) external {
       CollectionRequest storage collection = collectionRequests[_requestID];

       if (msg.sender != collection.recyclerAddress && msg.sender != collection.assignedCollector)
           revert waste.NOT_AUTHORIZED();

       if (collection.isCompleted) revert waste.ALREADY_COMPLETED();

       escrowContract.refundEscrow(collection.escrowRequestID);

       collection.isCompleted = true;

       emit CollectionRequestCanceled(_requestID);
   }
}