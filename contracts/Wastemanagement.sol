// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./libraries/Wastelibrary.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import "./libraries/GreenCycle.sol";
import "./libraries/UserLib.sol";
import "./libraries/RecyclerLib.sol";
import "./libraries/CollectorLib.sol";
import "./libraries/RequestLib.sol";

contract WasteManagement {
    IEscrow public escrowContract; // Address of the Escrow contract
    address owner;

    event UserCreated(address indexed userAddress, bool isRegistered);
    event LocationSet(address _user, int32 _latitude, int32 _longitude);
    event OfferCreated(
        address indexed recycler,
        string _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    );

    event collectorCreated(
        uint256 indexed collectorId,
        address indexed _collectorAddress,
        string _name,
        string _contact
    );

    event RequestCreated(
        uint256 requestID,
        address userAddress,
        uint256 offerId,
        uint256 weight,
        uint256 priceAgreed
    );

    event RequestConfirmed(uint256 requestID, address collectorAddress);
    event RequestCancelled(uint _requestId);
    event RequestAccepted(uint256 requestID, address collectorAddress);

    constructor(address _escrowContract) {
        escrowContract = IEscrow(_escrowContract);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    /**
     * @notice Creates a new user.
     * @dev accessible only to an unregistered user.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function _createUser(address _user) internal {
        UserLib.createUser(_user);
        emit UserCreated(_user, true);
    }

    /**
     * @notice Sets the user's location.
     * @param _latitude The latitude of the user's location.
     * @param _longitude The longitude of the user's location.
     * @dev accessible only to registered users.
     * @dev callable internally by functions when uploading/creating waste pickup requests
     */
    function _setUserLocation(
        address _user,
        int32 _latitude,
        int32 _longitude
    ) internal {
        UserLib.setUserLocation(_user, _latitude, _longitude);
        emit LocationSet(_user, _latitude, _longitude);
    }

    function getUser(
        address _userAddress
    ) external view returns (GreenCycle.User memory) {
        return UserLib.getUser(_userAddress);
    }

    /*******************************RECYCLERS*********************************************/

    function recyclerOffers(
        address _addr
    ) external view returns (GreenCycle.Offer[] memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.recyclerOffers[_addr];
    }

    function createRecycler(
        address _recyclerAddress,
        string memory _location,
        int32 lat,
        int32 lon
    ) external returns (uint256, address, string memory, bool) {
        return
            RecyclerLib.createRecycler(_recyclerAddress, _location, lat, lon);
    }

    function recyclers(
        address _address
    ) external view returns (GreenCycle.Recycler memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.recyclers[_address];
    }

    function getRecyclerById(
        uint256 id
    ) external view returns (GreenCycle.Recycler memory) {
        return RecyclerLib.getRecyclerById(id);
    }

    function seeAllRecyclers()
        external
        view
        returns (GreenCycle.Recycler[] memory)
    {
        return RecyclerLib.seeAllRecyclers();
    }

    function createOffer(
        string memory _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    ) external {
        RecyclerLib.createOffer(_wasteType, _pricePerKg, _miniQuantity);
        emit OfferCreated(msg.sender, _wasteType, _pricePerKg, _miniQuantity);
    }

    function getRecyclerOffers(
        uint256 _id //Company Id
    ) external view returns (GreenCycle.Offer[] memory) {
        return RecyclerLib.getRecyclerOffers(_id);
    }

    function viewOffer(
        address _recyclerAddress,
        uint256 _offerId
    ) external view returns (GreenCycle.Offer memory) {
        return RecyclerLib.viewOffer(_recyclerAddress, _offerId);
    }

    function updateOffer(
        uint256 _offerId,
        string memory _name,
        address _recyclerAddress,
        uint256 _pricePerKg,
        uint256 _minQuantity
    ) external returns (GreenCycle.Offer memory) {
        return
            RecyclerLib.updateOffer(
                _offerId,
                _name,
                _recyclerAddress,
                _pricePerKg,
                _minQuantity
            );
    }
    /**************************COLLECTORS*****************************/
    function createCollector(
        address _collectorAddress,
        string memory _name,
        string memory _contact
    ) external {
        //should be set by recyclers/
        uint256 _id = CollectorLib.createCollector(
            _collectorAddress,
            _name,
            _contact
        );
        emit collectorCreated(_id, _collectorAddress, _name, _contact);
    }

    function getCollector(
        address _address
    ) external view returns (GreenCycle.Collector memory) {
        return CollectorLib.getCollector(_address);
    }

    // New function to get all collectors for a specific recycler
    function getRecyclerCollectors(
        address _recyclerAddress
    ) external view returns (GreenCycle.Collector[] memory) {
        return CollectorLib.getRecyclerCollectors(_recyclerAddress);
    }

    /********************REQUESTS*********************/

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
        RequestLib.makeRequest(
            _recyclerId,
            _offerId,
            _weight,
            _price,
            _latitude,
            _longitude,
            _location
        );

        emit RequestCreated(_recyclerId, msg.sender, _offerId, _weight, _price);
    }

    function getRecyclerRequests(
        uint256 _recyclerId
    ) external view returns (GreenCycle.WasteCollectionRequest[] memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.recyclerRequests[_recyclerId];
    }

    function getAllUserRequest()
        external
        view
        returns (GreenCycle.WasteCollectionRequest[] memory)
    {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.allUserRequest[msg.sender];
    }

    function showRequest(
        uint256 _requestID
    ) external view returns (GreenCycle.WasteCollectionRequest memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        if (gs.userWasteRequests[_requestID].id == 0)
            revert waste.REQUESTNOTFOUND();
        return gs.userWasteRequests[_requestID];
    }

    function acceptRequest(
        uint256 _requestID,
        address _collectorAddress
    ) external payable {
        //should be called by the recycler
        RequestLib.acceptRequest(
            _requestID,
            _collectorAddress,
            msg.value,
            escrowContract
        );
        // Emit an event to indicate request acceptance
        emit RequestAccepted(_requestID, _collectorAddress);
    }

    function getAllCollectorRequests()
        external
        view
        returns (uint256[] memory)
    {
        return RequestLib.getAllCollectorRequests();
    }

    // should be called by the collector
    function confirmRequest(uint256 _requestID) external payable {
        RequestLib.confirmRequest(_requestID, escrowContract);
        emit RequestConfirmed(_requestID, msg.sender);
    }

    function userCancelRequest(uint256 _requestID) external {
        RequestLib.userCancelRequest(_requestID);
    }

    function cancelRequestAndRefund(uint256 _requestID) external {
        RequestLib.cancelRequestAndRefund(_requestID, escrowContract);
        emit RequestCancelled(_requestID);
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
        return UserLib.getUserRole(_userAddress);
    }

    function getAllUserRequests(
        address _addr
    ) external view returns (GreenCycle.WasteCollectionRequest[] memory) {
        GreenCycle.GreenCycleStorage storage gs = GreenCycle
            .greenCycleStorage();
        return gs.allUserRequest[_addr];
    }

    event FundsWithdrawn(address indexed owner, uint256 amount);

    function withdrawFunds() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) revert("No funds available for withdrawal");

        payable(msg.sender).transfer(contractBalance);

        emit FundsWithdrawn(msg.sender, contractBalance);
    }

    event LogFallback(address sender, uint value, bytes data);
    event LogReceive(address sender, uint value);

    /**
     * @notice Fallback function to log unexpected calls.
     */
    fallback() external payable {
        emit LogFallback(msg.sender, msg.value, msg.data);
    }

    /**
     * @notice Receive function to log ether sent directly to the contract.
     */
    receive() external payable {
        emit LogReceive(msg.sender, msg.value);
    }
}
