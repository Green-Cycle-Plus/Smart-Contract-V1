// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./Wastelibrary.sol";
import "./RecyclerLib.sol";
import "./CollectorLib.sol";

library UserLib {
    using RecyclerLib for RecyclerLib.RecyclerStorage;
    using CollectorLib for CollectorLib.CollectorStorage;

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

    struct UserStorage {
        mapping(address => User) users;
        uint256 numberOfUsers;
        RecyclerLib.RecyclerStorage recyclerAction;
        CollectorLib.CollectorStorage collectorAction;
    }

    event UserCreated(address indexed userAddress, bool isRegistered);
    event LocationSet(address _user, int32 _latitude, int32 _longitude);

    /**
     * @notice Creates a new user.
     * @dev accessible only to an unregistered user.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function createUser(
        UserStorage storage self,
        address _user
    ) internal returns (address, bool) {
        User storage user = self.users[_user];

        if (user.isRegistered) revert waste.REGISTERED();

        user.id = ++self.numberOfUsers; // Increment and assign ID
        user.userAddress = _user;
        user.isRegistered = true;
        emit UserCreated(_user, true);
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
        UserStorage storage self,
        address _user,
        int32 _latitude,
        int32 _longitude
    ) internal {
        if (!self.users[_user].isRegistered) revert waste.NOT_REGISTERED();

        self.users[_user].location = Coordinates(_latitude, _longitude);
        emit LocationSet(_user, _latitude, _longitude);
    }

    function getUser(
        UserStorage storage self,
        address _userAddress
    ) external view returns (User memory) {
        User storage user = self.users[_userAddress];
        return user;
    }

    function getUserRole(
        UserStorage storage self,
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
        // Check if the address is a user
        if (self.users[_userAddress].isRegistered) {
            User memory user = self.users[_userAddress];
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
        if (self.recyclerAction.recyclers[_userAddress].isRegistered) {
            RecyclerLib.Recycler memory recycler = self
                .recyclerAction
                .recyclers[_userAddress];
            Coordinates memory coord = self.recyclerAction.recyclerCordinates[
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

        if (self.collectorAction.collectors[_userAddress].id != 0) {
            CollectorLib.Collector storage collect = self
                .collectorAction
                .collectors[_userAddress];
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
