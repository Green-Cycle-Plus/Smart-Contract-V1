// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./GreenCycle.sol";

library UserLib {
    using GreenCycle for GreenCycle.GreenCycleStorage;

   

    /**
     * @notice Creates a new user.
     * @dev accessible only to an unregistered user.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function createUser(address _user) internal returns (address, bool) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.User storage user = gs.users[_user];
        if (user.isRegistered) revert waste.REGISTERED();
        user.id = ++gs.numberOfUsers; // Increment and assign ID
        user.userAddress = _user;
        user.isRegistered = true;
        return (_user, true);
    }

    /**
     * @notice Sets the user's location.
     * @param _latitude The latitude of the user's location.
     * @param _longitude The longitude of the user's location.
     * @dev accessible only to registered users.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function setUserLocation(
        address _user,
        int32 _latitude,
        int32 _longitude
    ) internal {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (!gs.users[_user].isRegistered) revert waste.NOT_REGISTERED();

        gs.users[_user].location = GreenCycle.Coordinates(
            _latitude,
            _longitude
        );
    }

    function getUser(
        address _userAddress
    ) external view returns (GreenCycle.User memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        GreenCycle.User storage user = gs.users[_userAddress];
        return user;
    }

    function getUserRole(
        address _userAddress
    )
        external
        view
        returns (
            string memory role,
            uint256 id,
            address addr,
            int32 latitude,
            int32 longitude,
            string memory location,
            bool isRegistered
        )
    {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        // Check if the address is a user
        if (gs.users[_userAddress].isRegistered) {
            GreenCycle.User memory user = gs.users[_userAddress];
            return (
                "User",
                user.id,
                user.userAddress,
                user.location.latitude,
                user.location.longitude,
                "",
                user.isRegistered
            );
        }

        // Check if the address is a recycler
        if (gs.recyclers[_userAddress].isRegistered) {
            GreenCycle.Recycler memory recycler = gs.recyclers[_userAddress];
            GreenCycle.Coordinates memory coord = gs.recyclerCordinates[
                _userAddress
            ];
            return (
                "Recycler",
                recycler.id,
                recycler.recyclerAddress,
                coord.latitude,
                coord.longitude,
                recycler.location,
                recycler.isRegistered
            );
        }

        if (gs.collectors[_userAddress].id != 0) {
            GreenCycle.Collector storage collect = gs.collectors[_userAddress];
            return (
                "collector",
                collect.id,
                collect.collectorAddress,
                0,
                0,
                "",
                true
            );
        }

        // If no match is found, revert
        revert waste.NOT_FOUND();
    }
}
