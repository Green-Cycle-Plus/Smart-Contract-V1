// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./GreenCycle.sol";
import "./UserLib.sol";
import "../interfaces/IEscrow.sol";

library RequestLib {
    using GreenCycle for GreenCycle.GreenCycleStorage;

    event CollectionRequestCanceled(uint requestID);
    event NewUserJoined(address userAddress, int32 latitude, int32 longitude);

    //should be called by users
    function makeRequest(
        uint256 _recyclerId,
        uint8 _offerId,
        uint32 _weight,
        uint256 _price,
        int32 _latitude,
        int32 _longitude,
        string memory _location
    ) external {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.Recycler memory recycler = gs.recyclersById[_recyclerId];
        GreenCycle.User storage user = gs.users[msg.sender];

        // Ensure user and recycler are registered
        if (!user.isRegistered) {
            UserLib.createUser(msg.sender);
            UserLib.setUserLocation(msg.sender, _latitude, _longitude);
            emit NewUserJoined(msg.sender, _latitude, _longitude);
        }

        if (!recycler.isRegistered) revert waste.RECYCLERNOTFOUND();

        if (_price < 0) revert waste.INVALIDAMOUNT();

        GreenCycle.Offer memory offer = gs.recyclerOffers[
            recycler.recyclerAddress
        ][_offerId];

        // Check if the recycler offers the specified waste type
        // if (offer.offerId == 0) revert waste.OFFERNOTFOUND();

        if (_weight < offer.minQuantity) revert waste.LOWER_THAN_MINQUANTITY();

        uint256 _requestID = ++gs.numOfRequest;

        GreenCycle.WasteCollectionRequest storage req = gs.userWasteRequests[
            _requestID
        ];

        user.totalWasteSubmited += 1;

        req.id = _requestID;
        req.userAddress = msg.sender;
        req.recyclerAddress = recycler.recyclerAddress;
        req.offerId = _offerId;
        req.weight = _weight;
        req.valuedAt = _price;
        req.status = GreenCycle.RequestStatus.PENDING;
        req.wasteType = offer.name;
        req.longitude = _longitude;
        req.latitude = _latitude;
        req.location = _location;

        gs.allUserRequest[msg.sender].push(req);

        gs.recyclerRequests[_recyclerId].push(req);
    }

    function acceptRequest(
        uint256 _requestID,
        address _collectorAddress,
        uint256 _amount,
        IEscrow escrowContract
    ) external {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        //should be called by the recycler

        GreenCycle.Collector storage collector = gs.collectors[
            _collectorAddress
        ];
        GreenCycle.WasteCollectionRequest storage req = gs.userWasteRequests[
            _requestID
        ];

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

        req.status = GreenCycle.RequestStatus.ACCEPTED;

        ++collector.numberOfWasteCollected;

        GreenCycle.Recycler storage recyler = gs.recyclers[req.recyclerAddress];
        GreenCycle.Recycler storage recylerByIdd = gs.recyclersById[recyler.id];

        ++recyler.totalWasteRequest;
        ++recylerByIdd.totalWasteRequest;

        // Update collector availability
        // collector.isAvailable = false;

        // Create the escrow and then retrieve the current escrow ID from EscrowContract
        uint256 escrowId = escrowContract.createEscrow{value: req.valuedAt}(
            req.userAddress,
            req.recyclerAddress,
            0
        );

        req.escrowRequestID = escrowId;

        GreenCycle.WasteCollectionRequest[] storage allUserReq = gs
            .allUserRequest[req.userAddress];
        GreenCycle.WasteCollectionRequest[] storage recyReq = gs
            .recyclerRequests[recyler.id];

        for (uint256 i = 0; i < allUserReq.length; i++) {
            if (allUserReq[i].id == _requestID) {
                allUserReq[i].status = GreenCycle.RequestStatus.ACCEPTED;
                break;
            }
        }

        for (uint256 k = 0; k < recyReq.length; k++) {
            if (recyReq[k].id == _requestID) {
                recyReq[k].status = GreenCycle.RequestStatus.ACCEPTED;
                break;
            }
        }

        gs.collectorsRequests[_collectorAddress].push(_requestID);
    }

    function getAllCollectorRequests()
        external
        view
        returns (uint256[] memory)
    {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (gs.collectors[msg.sender].collectorAddress == address(0))
            revert waste.NOT_FOUND();
        return gs.collectorsRequests[msg.sender];
    }

    // should be called by the collector
    function confirmRequest(
        uint256 _requestID,
        IEscrow escrowContract
    ) external {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();

        GreenCycle.WasteCollectionRequest storage req = gs.userWasteRequests[
            _requestID
        ];

        // Ensure the request is accepted and not already completed
        if (req.assignedCollector != msg.sender) revert waste.NOT_ASSIGNED();

        if (!req.isAccepted) revert waste.NOT_ACCEPTED_YET();

        if (req.isCompleted) revert waste.ALREADY_COMPLETED();

        // Mark the request as completed
        req.isCompleted = true;
        req.status = GreenCycle.RequestStatus.COMPLETED;

        //Update User Reward
        uint256 platformShare = (req.valuedAt * 10) / 100;
        uint256 userShare = req.valuedAt - platformShare;

        GreenCycle.User storage user = gs.users[req.userAddress];
        user.totalReward += userShare;

        GreenCycle.Recycler storage recyler = gs.recyclers[req.recyclerAddress];

        GreenCycle.Recycler storage recylerByIdd = gs.recyclersById[recyler.id];

        recyler.totalWasteCollectedInKgs += req.weight;
        recyler.totalAmountSpent += req.valuedAt;

        recylerByIdd.totalWasteCollectedInKgs += req.weight;
        recylerByIdd.totalAmountSpent += req.valuedAt;

        escrowContract.releaseEscrow(req.escrowRequestID);

        GreenCycle.WasteCollectionRequest[] storage allUserReq = gs
            .allUserRequest[req.userAddress];
        GreenCycle.WasteCollectionRequest[] storage recyReq = gs
            .recyclerRequests[recyler.id];

        for (uint256 i = 0; i < allUserReq.length; i++) {
            if (allUserReq[i].id == _requestID) {
                allUserReq[i].status = GreenCycle.RequestStatus.COMPLETED;
                break;
            }
        }

        for (uint256 k = 0; k < recyReq.length; k++) {
            if (recyReq[k].id == _requestID) {
                recyReq[k].status = GreenCycle.RequestStatus.COMPLETED;
                break;
            }
        }

        // Set the collector's availability back to true
        // Collector storage collector = collectors[msg.sender][req.assignedCollector];
        // collector.isAvailable = true;
    }

    function userCancelRequest(uint256 _requestID) external {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.WasteCollectionRequest storage req = gs.userWasteRequests[
            _requestID
        ];

        if (req.id == 0) revert waste.REQUESTNOTFOUND();

        if (req.userAddress != msg.sender) revert waste.NOT_AUTHORIZED();

        if (req.isCompleted) revert waste.ALREADY_COMPLETED();

        if (req.isAccepted) {
            // escrowContract.refundEscrow(req.escrowRequestID);
            revert waste.ALREADY_ACCEPTED();
        }
        req.status = GreenCycle.RequestStatus.CANCELLED;
        GreenCycle.Recycler storage recyler = gs.recyclers[req.recyclerAddress];

        GreenCycle.WasteCollectionRequest[] storage allUserReq = gs
            .allUserRequest[req.userAddress];
        GreenCycle.WasteCollectionRequest[] storage recyReq = gs
            .recyclerRequests[recyler.id];

        for (uint256 i = 0; i < allUserReq.length; i++) {
            if (allUserReq[i].id == _requestID) {
                allUserReq[i].status = GreenCycle.RequestStatus.CANCELLED;
                break;
            }
        }

        for (uint256 k = 0; k < recyReq.length; k++) {
            if (recyReq[k].id == _requestID) {
                recyReq[k].status = GreenCycle.RequestStatus.CANCELLED;
                break;
            }
        }
    }

    function cancelRequestAndRefund(
        uint256 _requestID,
        IEscrow escrowContract
    ) external {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.WasteCollectionRequest storage req = gs.userWasteRequests[
            _requestID
        ];

        // Ensure the request isn't completed
        if (req.isCompleted) revert waste.ALREADY_COMPLETED();

        // Ensure only the recycler or the collector can cancel the request
        if (
            msg.sender != req.recyclerAddress &&
            msg.sender != req.assignedCollector
        ) revert waste.NOT_AUTHORIZED();

        // Mark the request as canceled to prevent future actions on it
        req.isCompleted = true;

        req.status = GreenCycle.RequestStatus.CANCELLED;

        // Trigger the refundEscrow function in the Escrow contract
        escrowContract.refundEscrow(req.escrowRequestID);
        GreenCycle.Recycler storage recyler = gs.recyclers[req.recyclerAddress];

        GreenCycle.WasteCollectionRequest[] storage allUserReq = gs
            .allUserRequest[req.userAddress];
        GreenCycle.WasteCollectionRequest[] storage recyReq = gs
            .recyclerRequests[recyler.id];

        for (uint256 i = 0; i < allUserReq.length; i++) {
            if (allUserReq[i].id == _requestID) {
                allUserReq[i].status = GreenCycle.RequestStatus.CANCELLED;
                break;
            }
        }

        for (uint256 k = 0; k < recyReq.length; k++) {
            if (recyReq[k].id == _requestID) {
                recyReq[k].status = GreenCycle.RequestStatus.CANCELLED;
                break;
            }
        }

        emit CollectionRequestCanceled(_requestID);
    }
}
