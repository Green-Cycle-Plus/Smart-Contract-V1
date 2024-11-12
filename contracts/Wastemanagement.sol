// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import{waste} from "./libraries/Wastelibrary.sol";


contract WasteManagement{




    uint256 numberOfUsers;

    struct User { 
              
    uint256 id;
    address userAddress;
    string location;
    uint256 rating;
    bool isRegistered;

    }


    event RequestCreated(uint256 requestID, address userAddress, address recyclerAddress, string wasteType, uint256 weight, uint256 priceAgreed);
    event RequestAccepted(uint256 requestID, address collectorAddress);


    mapping(address => User) public users;


    function createUser( address _userAddress, string memory _location, uint256 _ratings ) external {

        User storage user = users[_userAddress];

        require( user.isRegistered == false , waste.REGISTERED() );

        uint256 _id = numberOfUsers+1;
        user.id = _id;
        user.userAddress = _userAddress;
        user.location = _location;
        user.rating = _ratings;
        user.isRegistered = true;

        numberOfUsers++;

    }


    function getUser(address _userAddress) external view returns ( uint256 id,address userAddress,  string memory location, uint256 rating, bool isRegistered ){

        User storage user = users[_userAddress];

        return (  user.id , user.userAddress , user.location ,user.rating, user.isRegistered );
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
    //bool isActive;

    }

    struct Offer {

    uint256 pricePerKg;
    uint256 minQuantity;

    }


    mapping(address => Recycler) public recyclers; 

    address[] recyclersAddresses;

    function createRecycler(address _recyclerAddress, string memory _location, uint256 _rating) external {

        uint256 _id =  numberOfRecyclers+1;

        Recycler storage recycler = recyclers[_recyclerAddress];

        recycler.id = _id;
        recycler.recyclerAddress = _recyclerAddress;
        recycler.location = _location;
        recycler.rating = _rating;
        recycler.isRegistered = true;
        //recycler.isActive = true;                     a function to toggle activeness can be created
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

    uint256 numOfCollector;
    
    struct Collector {
    uint256 id;
    address collectorAddress;
    bool isAvailable;
    }

    mapping(address => Collector) public collectors;

    function createCollector( address _collectorAddress )external {

        uint256 _id = numOfCollector+1; 
        Collector storage collector = collectors[_collectorAddress ];

        collector.id = _id;
        collector.collectorAddress = _collectorAddress;
        collector.isAvailable = true;

        numOfCollector++;

    }


    uint256 numOfRequest;

    struct CollectionRequest {

    uint256 id;
    address userAddress;
    address recyclerAddress;
    string wasteType;
    uint256 weight;
    uint256 priceAgreed;
    bool isCompleted;
    bool isAccepted;  // to track if the request is accepted
    address assignedCollector; // Collector who accepted the request

    }

    mapping(uint256 => CollectionRequest) public collectionRequests;

    function makekRequest( address _userAddress, address _recyclerAddress, string memory _wasteType, uint256 _weight, uint256 _price)external {

        User memory user = users[_userAddress];
        Recycler storage recycler = recyclers[_recyclerAddress];
        
          // Ensure user and recycler are registered
        require( user.isRegistered == true , waste.NOT_REGISTERED());
        require(recycler.isRegistered == true, waste.NOT_REGISTERED());


        // Check if the recycler offers the specified waste type
        Offer memory offer = recycler.offers[_wasteType];
        require(offer.pricePerKg > 0, waste.NOT_AMONG_OFFERS());

        // Optional: Validate minimum weight
        require(_weight >= offer.minQuantity, waste.LOWER_THAN_MINQUANTITY());
        
        // Generate a new request ID
        uint256 _requestID = numOfRequest+1;

        CollectionRequest storage collection = collectionRequests[_requestID];

        collection.id = _requestID;
        collection.userAddress = _userAddress;
        collection.recyclerAddress = _recyclerAddress;
        collection.wasteType = _wasteType;
        collection.weight = _weight;
        collection.priceAgreed = _price;
        collection.isCompleted = false;
        collection.isAccepted = false;


        numOfRequest++;         // Increment the number of requests

        // Emit event to indicate the creation of a new request
        emit RequestCreated(_requestID, _userAddress, _recyclerAddress, _wasteType, _weight, _price);
    
    }


    function showRequest(uint256 _requestID) external view returns (CollectionRequest memory )  {

        return collectionRequests[_requestID];


    }


    function acceptRequest(uint256 _requestID) external {

    CollectionRequest storage collection = collectionRequests[_requestID];
    Collector storage collector = collectors[msg.sender];

    // Ensure collector is registered and available
    require(collector.collectorAddress == msg.sender, waste.NOT_REGISTERED());
    require(collector.isAvailable, waste.NOT_AVAILABLE());
    require(!collection.isAccepted, waste.ALLREADY_ACCEPTED());

    // Mark request as accepted
    collection.isAccepted = true;
    collection.isCompleted = false;  // Mark as in progress
    collection.assignedCollector = msg.sender;

    // Update collector availability
    collector.isAvailable = false;

    // Emit an event to indicate request acceptance
    emit RequestAccepted(_requestID, msg.sender);

}



}


