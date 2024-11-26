// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./GreenCycle.sol";

library CollectorLib {
    using GreenCycle for GreenCycle.GreenCycleStorage;

    event collectorCreated(
        uint256 indexed collectorId,
        address indexed _collectorAddress,
        string _name,
        string _contact
    );

    function getCollector(
        address _address
    ) external view returns (GreenCycle.Collector memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.Collector storage col = gs.collectors[_address];
        if (col.collectorAddress == address(0)) revert waste.NOT_FOUND();
        return gs.collectors[_address];
    }

    function createCollector(
        address _collectorAddress,
        string memory _name,
        string memory _contact
    ) external {
        //should be set by recyclers/
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.Recycler storage recycler = gs.recyclers[msg.sender];

        if (recycler.recyclerAddress != msg.sender)
            revert waste.NOT_AUTHORIZED();
        if (gs.collectors[_collectorAddress].id != 0)
            revert waste.COLLECTORALREADYADDED();

        uint256 _id = gs.numOfCollector++;
        GreenCycle.Collector storage collector = gs.collectors[
            _collectorAddress
        ];

        collector.id = _id;
        collector.name = _name;
        collector.collectorAddress = _collectorAddress;
        collector.contact = _contact;
        collector.numberOfWasteCollected = 0;
        collector.isAvailable = true;

        // Add collector to recycler's collectors list
        gs.recyclerCollectors[msg.sender].push(collector);
        emit collectorCreated(_id, _collectorAddress, _name, _contact);
    }

    function getRecyclerCollectors(
        address _recyclerAddress
    ) external view returns (GreenCycle.Collector[] memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (!gs.recyclers[_recyclerAddress].isRegistered)
            revert waste.RECYCLERNOTFOUND();

        return gs.recyclerCollectors[_recyclerAddress];
    }
}
