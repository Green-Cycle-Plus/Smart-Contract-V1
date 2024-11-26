// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./GreenCycle.sol";

library RecyclerLib {
    using GreenCycle for GreenCycle.GreenCycleStorage;

    event RecyclerCreated(
        address indexed _recyclerAddress,
        uint256 indexed _recyclerId,
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
    ) external returns (uint256, address, string memory, bool) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (gs.recyclers[_recyclerAddress].isRegistered == true)
            revert waste.RECYCLER_ALREADY_REGISTERED();

        if (lat == 0) revert waste.INVALIDLATITUTUDE();
        if (lon == 0) revert waste.INVALIDLONGITUDE();

        uint256 _id = ++gs.numberOfRecyclers;

        GreenCycle.Recycler storage recycler = gs.recyclers[_recyclerAddress];

        recycler.id = _id;
        recycler.recyclerAddress = _recyclerAddress;
        recycler.location = _location;
        recycler.isRegistered = true;

        gs.allRecyclers.push(recycler);
        GreenCycle.Coordinates storage cord = gs.recyclerCordinates[
            _recyclerAddress
        ];
        cord.latitude = lat;
        cord.longitude = lon;

        gs.recyclersById[_id] = recycler;

        emit RecyclerCreated(_recyclerAddress, _id, _location, lat, lon);
        return (_id, _recyclerAddress, _location, true);
    }

    function getRecyclerById(
        uint256 id
    ) external view returns (GreenCycle.Recycler memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.recyclersById[id];
    }

    function seeAllRecyclers()
        external
        view
        returns (GreenCycle.Recycler[] memory)
    {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.allRecyclers;
    }

    function createOffer(
        string memory _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    ) external {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (!gs.recyclers[msg.sender].isRegistered)
            revert waste.INVALIDRECYCLER();
        if (bytes(_wasteType).length < 3) revert waste.INVALIDOFFERNAME();
        if (_pricePerKg <= 0) revert waste.INVALIDPRICE();
        if (_miniQuantity == 0) revert waste.INVALIDQUANTITY();
        uint256 offerId = gs.recyclerOffers[msg.sender].length;
        gs.recyclerOffers[msg.sender].push(
            GreenCycle.Offer({
                offerId: offerId + 1,
                name: _wasteType,
                recyclerAddress: msg.sender,
                recyclerId: gs.recyclers[msg.sender].id,
                pricePerKg: _pricePerKg,
                minQuantity: _miniQuantity
            })
        );

        emit OfferCreated(msg.sender, _wasteType, _pricePerKg, _miniQuantity);
    }

    function getRecyclerOffers(
        uint256 _id //Company Id
    ) external view returns (GreenCycle.Offer[] memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.Recycler storage recycler = gs.recyclersById[_id];
        if (recycler.recyclerAddress == address(0)) revert waste.NOT_FOUND();
        return gs.recyclerOffers[recycler.recyclerAddress];
    }

    function viewOffer(
        address _recyclerAddress,
        uint256 _offerId
    ) external view returns (GreenCycle.Offer memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (!gs.recyclers[_recyclerAddress].isRegistered)
            revert waste.INVALIDRECYCLER();

        if (gs.recyclerOffers[_recyclerAddress][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        return gs.recyclerOffers[_recyclerAddress][_offerId];
    }

    function updateOffer(
        uint256 _offerId,
        string memory _name,
        address _recyclerAddress,
        uint256 _pricePerKg,
        uint256 _minQuantity
    ) external returns (GreenCycle.Offer memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (!gs.recyclers[msg.sender].isRegistered)
            revert waste.INVALIDRECYCLER();

        if (gs.recyclerOffers[msg.sender][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        GreenCycle.Offer storage offer = gs.recyclerOffers[msg.sender][
            _offerId
        ];
        offer.name = _name;
        offer.recyclerAddress = _recyclerAddress;
        offer.pricePerKg = _pricePerKg;
        offer.minQuantity = _minQuantity;

        return offer;
    }
}
