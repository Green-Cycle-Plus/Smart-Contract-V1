// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import{waste} from "./libraries/Wastelibrary.sol";
import{IEscrow} from "./IEscrow.sol";



    contract WasteManagement{

    IEscrow public escrowContract;  // Address of the Escrow contract

    constructor(address _escrowContract) {

    escrowContract = IEscrow( _escrowContract);
    
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


    event RequestCreated(uint256 requestID, address userAddress, address recyclerAddress, string wasteType, uint256 weight, uint256 priceAgreed);
    event RequestAccepted(uint256 requestID, address collectorAddress);
    event RequestConfirmed(uint256 requestID, address collectorAddress);
    event CollectionRequestCanceled(uint requestID);



    mapping(address => User) public users;


    function createUser() external {

        User storage user = users[msg.sender];

        if(user.isRegistered == true) revert waste.REGISTERED();

        uint256 _id = ++numberOfUsers;
        user.id = _id;
        user.userAddress = msg.sender;

        user.isRegistered = true;

        numberOfUsers++;

    }


    function setUserLocation(int32 latitude, int32 longitude) external {

    if(!users[msg.sender].isRegistered) revert  waste.NOT_REGISTERED();

    users[msg.sender].location = Coordinates(latitude, longitude);

    }



    /************************************************************************************************************************************************************************************/



    uint256 public numberOfRecyclers;

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


    mapping(address => Recycler) public recyclers; 

    address[] recyclersAddresses;

    function createRecycler(address _recyclerAddress, string memory _location, uint256 _rating) external {

        uint256 _id =  ++numberOfRecyclers;

        Recycler storage recycler = recyclers[_recyclerAddress];

        recycler.id = _id;
        recycler.recyclerAddress = _recyclerAddress;
        recycler.location = _location;
        recycler.rating = _rating;
        recycler.isRegistered = true;
        recyclersAddresses.push(_recyclerAddress);

        numberOfRecyclers++;

    }


    function seeAllRecyclers()external view returns (address[] memory){

        return  recyclersAddresses;
    }

   


    function createOffer( address _recyclerAddress,string memory _wasteType, uint256 _pricePerKg, uint256 _miniQuantity)external {

        
        Recycler storage recycler = recyclers[_recyclerAddress];

        Offer storage offer = recycler.offers[_wasteType];

        offer.pricePerKg = _pricePerKg;

        offer.minQuantity = _miniQuantity;
       
        
    }


    function viewOffer(address _recyclerAddress,string memory _wasteType) external view returns (uint256 pricePerKg, uint256 minQuantity) {

        Recycler storage recycler = recyclers[_recyclerAddress];

        Offer memory offer = recycler.offers[_wasteType];

        return (offer.pricePerKg, offer.minQuantity);

    }




 /************************************************************************************************************************************************************************************/

    uint256 numOfRequest;

    struct CollectionRequest {                                      //should be called by users

    uint256 id;
    address userAddress;
    address recyclerAddress;
    string wasteType;
    uint256 weight;
    uint256 priceAgreed;
    uint256 paymentAmount;  // Payment amount in tokens
    bool isCompleted;
    bool isAccepted;  // to track if the request is accepted
    uint256 escrowRequestID;  // Reference to the escrow contract request ID

    }

    mapping(uint256 => CollectionRequest) public collectionRequests;

    function makekRequest(  address _recyclerAddress, string memory _wasteType, uint256 _weight, uint256 _price)external {

        User memory user = users[msg.sender];

        Recycler storage recycler = recyclers[_recyclerAddress];

        if(user.userAddress != msg.sender) revert waste.NOT_AUTHORIZED();
        
        // Ensure user and recycler are registered
        if( !user.isRegistered) revert waste.NOT_REGISTERED();

        if(!recycler.isRegistered) revert waste.NOT_REGISTERED();

        if(_price < 0) revert waste.PAYMENT_REQUIRED(); // Ensure payment is provided

        // Check if the recycler offers the specified waste type
        Offer memory offer = recycler.offers[_wasteType];

        if(offer.pricePerKg < 0) revert waste.NOT_AMONG_OFFERS();

        if(_weight < offer.minQuantity) revert waste.LOWER_THAN_MINQUANTITY();

        
        uint256 _requestID = ++numOfRequest;

   

        CollectionRequest storage collection = collectionRequests[_requestID];

        collection.id = _requestID;
        collection.userAddress = msg.sender;
        collection.recyclerAddress = _recyclerAddress;
        collection.wasteType = _wasteType;
        collection.weight = _weight;
        collection.priceAgreed = _price;
        collection.isAccepted = false;
        collection.isCompleted = false;
        collection.escrowRequestID = 0;

        numOfRequest++;

        emit RequestCreated(_requestID, msg.sender, _recyclerAddress, _wasteType, _weight, _price);
    
    }


    function showRequest(uint256 _requestID) external view returns (CollectionRequest memory )  {

        return collectionRequests[_requestID];


    }


    function acceptRequest(uint256 _requestID ) external {                           //should be called by the recycler

    CollectionRequest storage collection = collectionRequests[_requestID];

    if(collection.recyclerAddress != msg.sender) revert waste. ONLY_A_RECYCLER();

    if(collection.isAccepted) revert waste.ALLREADY_ACCEPTED();

    if(collection.isCompleted) revert waste.ALREADY_COMPLETED();

    // Mark request as accepted
    collection.isAccepted = true;

    // Create the escrow and then retrieve the current escrow ID from EscrowContract
    uint256 escrowId = escrowContract.createEscrow{value: collection.priceAgreed}(collection.userAddress);

    collection.escrowRequestID  = escrowId;

    // Emit an event to indicate request acceptance
    emit RequestAccepted(_requestID, msg.sender );

    }


    function confirmRequest(uint256 _requestID) external {             // should be called by the recycler

    CollectionRequest storage collection = collectionRequests[_requestID];

    // Ensure the request is accepted and not already completed

   if(collection.recyclerAddress != msg.sender) revert waste. ONLY_A_RECYCLER();

    if(!collection.isAccepted) revert waste.NOT_ACCEPTED_YET();

    if(collection.isCompleted) revert waste.ALREADY_COMPLETED();
    

    // Mark the request as completed
    collection.isCompleted = true;  

    escrowContract.releaseEscrow(collection.escrowRequestID);

    // Emit an event indicating the completion of the request
    emit RequestConfirmed(_requestID, msg.sender);

    }


    function cancelRequestAndRefund(uint256 _requestID) external {

    CollectionRequest storage collection = collectionRequests[_requestID];

    // Ensure only the recycler or the collector can cancel the request
    if(  msg.sender != collection.recyclerAddress )  revert  waste.NOT_AUTHORIZED();

    if(collection.isCompleted) revert waste.ALREADY_COMPLETED(); // Ensure the request isn't completed

    // Trigger the refundEscrow function in the Escrow contract
    escrowContract.refundEscrow(collection.escrowRequestID);

    // Mark the request as canceled to prevent future actions on it
    collection.isCompleted = true;

    emit CollectionRequestCanceled(_requestID);
    
    }



}