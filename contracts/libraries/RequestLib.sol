// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./UserLib.sol";
import "./RecyclerLib.sol";
import "./CollectorLib.sol";
import "../interfaces/IEscrow.sol";

library RequestLib {
    using UserLib for UserLib.UserStorage;
    using RecyclerLib for RecyclerLib.RecyclerStorage;
    using CollectorLib for CollectorLib.CollectorStorage;

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
        uint32 valuedAt;
        uint8 offerId;
        int32 longitude;
        int32 latitude;
        address userAddress;
        bool isCompleted;
        RequestStatus status;
        address recyclerAddress;
        address assignedCollector; // Collector who accepted the request
        bool isAccepted; // to track if the request is accepted
    }

    struct RequestStorage {
        uint256 numOfRequest;
        mapping(uint256 => WasteCollectionRequest) userWasteRequests;
        mapping(address => WasteCollectionRequest[]) allUserRequest; //Users array of Users Request IDs.
        mapping(address => uint256[]) collectorsRequests;
        mapping(uint256 => WasteCollectionRequest[]) recyclerRequests;
        RecyclerLib.RecyclerStorage recyclerAction;
        UserLib.UserStorage userAction;
        CollectorLib.CollectorStorage collectorAction;
    }

    event RequestCancelled(uint _requestId);
    event RequestAccepted(uint256 requestID, address collectorAddress);
    event RequestConfirmed(uint256 requestID, address collectorAddress);
    event CollectionRequestCanceled(uint requestID);
    event NewUserJoined(address userAddress, int32 latitude, int32 longitude);
    event RequestCreated(
        uint256 requestID,
        address userAddress,
        address recyclerAddress,
        uint256 offerId,
        uint256 weight,
        uint256 priceAgreed
    );

    //should be called by users
    function makeRequest(
        RequestStorage storage self,
        uint256 _recyclerId,
        uint8 _offerId,
        uint32 _weight,
        uint32 _price,
        int32 _latitude,
        int32 _longitude
    ) external {
        // UserLib.User memory user = self.userAction.users[msg.sender];
        RecyclerLib.Recycler memory recycler = self
            .recyclerAction
            .recyclersById[_recyclerId];

        // Ensure user and recycler are registered
        // if (!user.isRegistered) {
        //     _createUser(msg.sender);
        //     _setUserLocation(msg.sender, _latitude, _longitude);
        //     emit NewUserJoined(msg.sender, _latitude, _longitude);
        // }

        if (!recycler.isRegistered) revert waste.RECYCLERNOTFOUND();

        if (_price < 0) revert waste.INVALIDAMOUNT();

        RecyclerLib.Offer memory offer = self.recyclerAction.recyclerOffers[
            recycler.recyclerAddress
        ][_offerId];

        // Check if the recycler offers the specified waste type
        if (offer.offerId == 0) revert waste.OFFERNOTFOUND();

        if (_weight < offer.minQuantity) revert waste.LOWER_THAN_MINQUANTITY();

        uint256 _requestID = ++self.numOfRequest;

        WasteCollectionRequest storage req = self.userWasteRequests[_requestID];

        req.id = _requestID;
        req.userAddress = msg.sender;
        req.recyclerAddress = recycler.recyclerAddress;
        req.offerId = _offerId;
        req.weight = _weight;
        req.valuedAt = _price;
        req.status = RequestStatus.PENDING;
        req.wasteType = offer.name;
        req.longitude = _longitude;
        req.latitude = _latitude;

        self.allUserRequest[msg.sender].push(req);

        self.recyclerRequests[_recyclerId].push(req);

        emit RequestCreated(
            _requestID,
            msg.sender,
            recycler.recyclerAddress,
            _offerId,
            _weight,
            _price
        );
    }

    function getRecyclerRequests(
        RequestStorage storage self,
        uint256 _recyclerId
    ) external view returns (WasteCollectionRequest[] memory) {
        return self.recyclerRequests[_recyclerId];
    }

    function getAllUserRequest(
        RequestStorage storage self
    ) external view returns (WasteCollectionRequest[] memory) {
        return self.allUserRequest[msg.sender];
    }

    function showRequest(
        RequestStorage storage self,
        uint256 _requestID
    ) external view returns (WasteCollectionRequest memory) {
        if (self.userWasteRequests[_requestID].id == 0)
            revert waste.REQUESTNOTFOUND();
        return self.userWasteRequests[_requestID];
    }

    function acceptRequest(
        RequestStorage storage self,
        uint256 _requestID,
        address _collectorAddress,
        uint256 _amount,
        IEscrow escrowContract
    ) external {
        //should be called by the recycler

        CollectorLib.Collector storage collector = self
            .collectorAction
            .collectors[_collectorAddress];
        WasteCollectionRequest storage req = self.userWasteRequests[_requestID];

        if (req.recyclerAddress != msg.sender) revert waste.ONLY_A_RECYCLER();

        if (req.isAccepted) revert waste.ALLREADY_ACCEPTED();

        if (req.isCompleted) revert waste.ALREADY_COMPLETED();
        if (req.assignedCollector != address(0))
            revert waste.REQUESTALREADYASSIGNED();

        if (_amount < req.valuedAt)
            revert waste.AMOUNT_LESS_THAN_AMOUNT_VALUED();

        // Collector storage collector = collectors[msg.sender][_collectorAddress];

        // Mark request as accepted
        req.isAccepted = true;
        //collection.isCompleted = false;  // Mark as in progress
        req.assignedCollector = _collectorAddress;

        ++collector.numberOfWasteCollected;

        // Update collector availability
        // collector.isAvailable = false;

        // Create the escrow and then retrieve the current escrow ID from EscrowContract
        uint256 escrowId = escrowContract.createEscrow{value: req.valuedAt}(
            req.userAddress,
            req.recyclerAddress,
            0
        );

        req.escrowRequestID = escrowId;

        self.collectorsRequests[_collectorAddress].push(_requestID);

        // Emit an event to indicate request acceptance
        emit RequestAccepted(_requestID, _collectorAddress);
    }

    function getAllCollectorRequests(
        RequestStorage storage self
    ) external view returns (uint256[] memory) {
        if (
            self.collectorAction.collectors[msg.sender].collectorAddress ==
            address(0)
        ) revert waste.NOT_FOUND();
        return self.collectorsRequests[msg.sender];
    }

    // should be called by the collector
    function confirmRequest(
        RequestStorage storage self,
        uint256 _requestID,
        IEscrow escrowContract
    ) external {
        WasteCollectionRequest storage req = self.userWasteRequests[_requestID];

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

    function userCancelRequest(
        RequestStorage storage self,
        uint256 _requestID
    ) external {
        WasteCollectionRequest storage req = self.userWasteRequests[_requestID];

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

    function cancelRequestAndRefund(
        RequestStorage storage self,
        uint256 _requestID,
        IEscrow escrowContract
    ) external {
        WasteCollectionRequest storage req = self.userWasteRequests[_requestID];

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
}
