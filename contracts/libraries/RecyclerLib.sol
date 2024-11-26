// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./UserLib.sol";

library RecyclerLib {
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
        uint256 recyclerId;
        uint256 pricePerKg;
        uint256 minQuantity;
    }

    struct RecyclerStorage {
        uint256 numberOfRecyclers;
        mapping(address => Offer[]) recyclerOffers; //RecylcerAddress => Offer
        mapping(address => Recycler) recyclers;
        mapping(uint256 => Recycler) recyclersById;
        Recycler[] allRecyclers;
        mapping(address => UserLib.Coordinates) recyclerCordinates;
    }

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
        RecyclerStorage storage self,
        address _recyclerAddress,
        string memory _location,
        int32 lat,
        int32 lon
    ) external returns (uint256, address, string memory, bool) {
        if (self.recyclers[_recyclerAddress].isRegistered == true)
            revert waste.RECYCLER_ALREADY_REGISTERED();

        if (lat == 0) revert waste.INVALIDLATITUTUDE();
        if (lon == 0) revert waste.INVALIDLONGITUDE();

        uint256 _id = ++self.numberOfRecyclers;

        Recycler storage recycler = self.recyclers[_recyclerAddress];

        recycler.id = _id;
        recycler.recyclerAddress = _recyclerAddress;
        recycler.location = _location;
        recycler.isRegistered = true;

        self.allRecyclers.push(recycler);

        UserLib.Coordinates storage cord = self.recyclerCordinates[
            _recyclerAddress
        ];
        cord.latitude = lat;
        cord.longitude = lon;

        self.recyclersById[_id] = recycler;

        emit RecyclerCreated(_recyclerAddress, _id, _location, lat, lon);
        return (_id, _recyclerAddress, _location, true);
    }

    function getRecyclerById(
        RecyclerStorage storage self,
        uint256 id
    ) external view returns (Recycler memory) {
        return self.recyclersById[id];
    }

    function seeAllRecyclers(RecyclerStorage storage self) external view returns (Recycler[] memory) {
        return self.allRecyclers;
    }

    function createOffer(
        RecyclerStorage storage self,
        string memory _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    ) external {
        if (!self.recyclers[msg.sender].isRegistered)
            revert waste.INVALIDRECYCLER();
        if (bytes(_wasteType).length < 3) revert waste.INVALIDOFFERNAME();
        if (_pricePerKg <= 0) revert waste.INVALIDPRICE();
        if (_miniQuantity == 0) revert waste.INVALIDQUANTITY();
        uint256 offerId = self.recyclerOffers[msg.sender].length;
        self.recyclerOffers[msg.sender].push(
            Offer({
                offerId: offerId + 1,
                name: _wasteType,
                recyclerAddress: msg.sender,
                recyclerId: self.recyclers[msg.sender].id,
                pricePerKg: _pricePerKg,
                minQuantity: _miniQuantity
            })
        );

        emit OfferCreated(msg.sender, _wasteType, _pricePerKg, _miniQuantity);
    }

    function getRecyclerOffers(
        RecyclerStorage storage self,
        uint256 _id //Company Id
    ) external view returns (Offer[] memory) {
        Recycler storage recycler = self.recyclersById[_id];
        if (recycler.recyclerAddress == address(0)) revert waste.NOT_FOUND();
        return self.recyclerOffers[recycler.recyclerAddress];
    }

    function viewOffer(
        RecyclerStorage storage self,
        address _recyclerAddress,
        uint256 _offerId
    ) external view returns (Offer memory) {
        if (!self.recyclers[_recyclerAddress].isRegistered)
            revert waste.INVALIDRECYCLER();

        if (self.recyclerOffers[_recyclerAddress][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        return self.recyclerOffers[_recyclerAddress][_offerId];
    }

    function updateOffer(
        RecyclerStorage storage self,
        uint256 _offerId,
        string memory _name,
        address _recyclerAddress,
        uint256 _pricePerKg,
        uint256 _minQuantity
    ) external returns (Offer memory) {
        if (!self.recyclers[msg.sender].isRegistered)
            revert waste.INVALIDRECYCLER();

        if (self.recyclerOffers[msg.sender][_offerId].offerId == 0)
            revert waste.OFFERNOTFOUND();

        Offer storage offer = self.recyclerOffers[msg.sender][_offerId];
        offer.name = _name;
        offer.recyclerAddress = _recyclerAddress;
        offer.pricePerKg = _pricePerKg;
        offer.minQuantity = _minQuantity;

        return offer;
    }
}
