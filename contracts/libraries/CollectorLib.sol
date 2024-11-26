// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./RecyclerLib.sol";

library CollectorLib {
    using RecyclerLib for RecyclerLib.RecyclerStorage;
    struct Collector {
        uint256 id;
        string name;
        address collectorAddress;
        string contact;
        uint256 numberOfWasteCollected;
        bool isAvailable;
    }

    struct CollectorStorage {
        mapping(address => Collector) collectors; //Collector Address => Collector.
        mapping(address => Collector[]) recyclerCollectors; // recycler address => array of collector addresses
        uint256 numOfCollector;
        RecyclerLib.RecyclerStorage recyclerAction;
    }

    event collectorCreated(
        uint256 indexed collectorId,
        address indexed _collectorAddress,
        string _name,
        string _contact
    );

    function getCollector(
        CollectorStorage storage self,
        address _address
    ) external view returns (Collector memory) {
        Collector storage col = self.collectors[_address];
        if (col.collectorAddress == address(0)) revert waste.NOT_FOUND();
        return self.collectors[_address];
    }

    function createCollector(
        CollectorStorage storage self,
        address _collectorAddress,
        string memory _name,
        string memory _contact
    ) external {
        //should be set by recyclers/

        // RecyclerLib.Recycler storage recycler = RecyclerLib.RecyclerStorage[
        //     recyclers[msg.sender]
        // ];
        RecyclerLib.Recycler storage recycler = self.recyclerAction.recyclers[
            msg.sender
        ];
        if (recycler.recyclerAddress != msg.sender)
            revert waste.NOT_AUTHORIZED();
        if (self.collectors[_collectorAddress].id != 0)
            revert waste.COLLECTORALREADYADDED();

        uint256 _id = self.numOfCollector++;

        Collector storage collector = self.collectors[_collectorAddress];

        collector.id = _id;
        collector.name = _name;
        collector.collectorAddress = _collectorAddress;
        collector.contact = _contact;
        collector.numberOfWasteCollected = 0;
        collector.isAvailable = true;

        // Add collector to recycler's collectors list
        self.recyclerCollectors[msg.sender].push(collector);
        emit collectorCreated(_id, _collectorAddress, _name, _contact);
    }

    function getRecyclerCollectors(
        CollectorStorage storage self,
        address _recyclerAddress
    ) external view returns (Collector[] memory) {
        if (!self.recyclerAction.recyclers[_recyclerAddress].isRegistered)
            revert waste.RECYCLERNOTFOUND();

        return self.recyclerCollectors[_recyclerAddress];
    }
}
