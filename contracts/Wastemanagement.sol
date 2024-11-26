// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {waste} from "./libraries/Wastelibrary.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import "./libraries/UserLib.sol";
import "./libraries/RecyclerLib.sol";
import "./libraries/CollectorLib.sol";
import "./libraries/RequestLib.sol";

contract WasteManagement {
    using UserLib for UserLib.UserStorage;
    using RecyclerLib for RecyclerLib.RecyclerStorage;
    using CollectorLib for CollectorLib.CollectorStorage;
    using RequestLib for RequestLib.RequestStorage;

    UserLib.UserStorage userAction;
    RecyclerLib.RecyclerStorage recyclerAction;
    CollectorLib.CollectorStorage collectorAction;
    RequestLib.RequestStorage requestAction;

    IEscrow public escrowContract; // Address of the Escrow contract
    address owner;

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
        userAction.createUser(_user);
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
        userAction.setUserLocation(_user, _latitude, _longitude);
    }

    function getUser(
        address _userAddress
    ) external view returns (UserLib.User memory) {
        return userAction.getUser(_userAddress);
    }

    /*******************************RECYCLERS*********************************************/

    function recyclerOffers(
        address _addr
    ) external view returns (RecyclerLib.Offer[] memory) {
        return recyclerAction.recyclerOffers[_addr];
    }

    function createRecycler(
        address _recyclerAddress,
        string memory _location,
        int32 lat,
        int32 lon
    ) external returns (uint256, address, string memory, bool) {
        return
            recyclerAction.createRecycler(
                _recyclerAddress,
                _location,
                lat,
                lon
            );
    }

    function recyclers(
        address _address
    ) external view returns (RecyclerLib.Recycler memory) {
        return recyclerAction.recyclers[_address];
    }

    function getRecyclerById(
        uint256 id
    ) external view returns (RecyclerLib.Recycler memory) {
        return recyclerAction.getRecyclerById(id);
    }

    function seeAllRecyclers()
        external
        view
        returns (RecyclerLib.Recycler[] memory)
    {
        return recyclerAction.seeAllRecyclers();
    }

    function createOffer(
        string memory _wasteType,
        uint256 _pricePerKg,
        uint256 _miniQuantity
    ) external {
        recyclerAction.createOffer(_wasteType, _pricePerKg, _miniQuantity);
    }

    function getRecyclerOffers(
        uint256 _id //Company Id
    ) external view returns (RecyclerLib.Offer[] memory) {
        return recyclerAction.getRecyclerOffers(_id);
    }

    function viewOffer(
        address _recyclerAddress,
        uint256 _offerId
    ) external view returns (RecyclerLib.Offer memory) {
        return recyclerAction.viewOffer(_recyclerAddress, _offerId);
    }

    function updateOffer(
        uint256 _offerId,
        string memory _name,
        address _recyclerAddress,
        uint256 _pricePerKg,
        uint256 _minQuantity
    ) external returns (RecyclerLib.Offer memory) {
        return
            recyclerAction.updateOffer(
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
        return
            collectorAction.createCollector(_collectorAddress, _name, _contact);
    }

    function getCollector(
        address _address
    ) external view returns (CollectorLib.Collector memory) {
        return collectorAction.getCollector(_address);
    }

    // New function to get all collectors for a specific recycler
    function getRecyclerCollectors(
        address _recyclerAddress
    ) external view returns (CollectorLib.Collector[] memory) {
        return collectorAction.getRecyclerCollectors(_recyclerAddress);
    }

    /********************REQUESTS*********************/

    //should be called by users
    function makeRequest(
        uint256 _recyclerId,
        uint8 _offerId,
        uint32 _weight,
        uint32 _price,
        int32 _latitude,
        int32 _longitude
    ) external {
        requestAction.makeRequest(
            _recyclerId,
            _offerId,
            _weight,
            _price,
            _latitude,
            _longitude
        );
    }

    function getRecyclerRequests(
        uint256 _recyclerId
    ) external view returns (RequestLib.WasteCollectionRequest[] memory) {
        return requestAction.getRecyclerRequests(_recyclerId);
    }

    function getAllUserRequest()
        external
        view
        returns (RequestLib.WasteCollectionRequest[] memory)
    {
        return requestAction.getAllUserRequest();
    }

    function showRequest(
        uint256 _requestID
    ) external view returns (RequestLib.WasteCollectionRequest memory) {
        return requestAction.showRequest(_requestID);
    }

    function acceptRequest(
        uint256 _requestID,
        address _collectorAddress
    ) external payable {
        //should be called by the recycler
        requestAction.acceptRequest(
            _requestID,
            _collectorAddress,
            msg.value,
            escrowContract
        );
    }

    function getAllCollectorRequests()
        external
        view
        returns (uint256[] memory)
    {
        return requestAction.getAllCollectorRequests();
    }

    // should be called by the collector
    function confirmRequest(uint256 _requestID) external payable {
        requestAction.confirmRequest(_requestID, escrowContract);
    }

    function userCancelRequest(uint256 _requestID) external {
        requestAction.userCancelRequest(_requestID);
    }

    function cancelRequestAndRefund(uint256 _requestID) external {
        requestAction.cancelRequestAndRefund(_requestID, escrowContract);
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
        return userAction.getUserRole(_userAddress);
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
