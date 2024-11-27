// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library GreenCycle {
    bytes32 constant GREENCYCLE_STORAGE_POSITION =
        keccak256("greencycle.storage.slot");

    struct Collector {
        uint256 id;
        string name;
        address collectorAddress;
        string contact;
        uint256 numberOfWasteCollected;
        bool isAvailable;
    }

    struct Recycler {
        uint256 id;
        address recyclerAddress;
        string location;
        uint256 rating;
        bool isRegistered;
        //bool isActive;
        uint256 totalWasteRequest;
        uint256 totalAmountSpent;
        uint256 totalWasteCollectedInKgs;
    }

    struct Offer {
        uint256 offerId;
        string name;
        address recyclerAddress;
        uint256 recyclerId;
        uint256 pricePerKg;
        uint256 minQuantity;
    }

    //User
    struct Coordinates {
        int32 latitude;
        int32 longitude;
    }

    struct User {
        uint256 id;
        address userAddress;
        Coordinates location;
        bool isRegistered;
        uint256 totalWasteSubmited;
        uint256 totalReward;
    }

    //Request

    enum RequestStatus {
        PENDING,
        ACCEPTED,
        COMPLETED,
        CANCELLED
    }

    struct WasteCollectionRequest {
        string wasteType;
        uint256 id;
        uint256 escrowRequestID; // Reference to the escrow contract request ID
        uint256 amountPaid; // Payment amount in tokens
        uint32 weight;
        uint256 valuedAt;
        uint8 offerId;
        int32 longitude;
        int32 latitude;
        address userAddress;
        bool isCompleted;
        RequestStatus status;
        address recyclerAddress;
        address assignedCollector; // Collector who accepted the request
        bool isAccepted; // to track if the request is accepted
        string location;
    }

    struct GreenCycleStorage {
        mapping(address => Collector) collectors; //Collector Address => Collector.
        mapping(address => Collector[]) recyclerCollectors; // recycler address => array of collector addresses
        uint256 numOfCollector;
        //RecyclerLib Storage
        uint256 numberOfRecyclers;
        mapping(address => Offer[]) recyclerOffers; //RecylcerAddress => Offer
        mapping(address => Recycler) recyclers;
        mapping(uint256 => Recycler) recyclersById;
        Recycler[] allRecyclers;
        mapping(address => Coordinates) recyclerCordinates;
        //User Lib Storage
        mapping(address => User) users;
        uint256 numberOfUsers;
        //Recyclers
        uint256 numOfRequest;
        mapping(uint256 => WasteCollectionRequest) userWasteRequests;
        mapping(address => WasteCollectionRequest[]) allUserRequest; //Users array of Users Request IDs.
        mapping(address => uint256[]) collectorsRequests;
        mapping(uint256 => WasteCollectionRequest[]) recyclerRequests;
    }

    function greenCycleStorage()
        internal
        pure
        returns (GreenCycleStorage storage gs)
    {
        bytes32 position = GREENCYCLE_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }
}
