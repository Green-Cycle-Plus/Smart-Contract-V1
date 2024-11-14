// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ErrorLib {
    error ZeroAddress();
    error UnAuthorized();
    error NotOwner();
    error InvalidCategoryName();
    error CategoryNotFound();
    error InvalidQuanity();
    error InvalidPrice();
    error InactiveProduct();
    error InvalidIpfsHash();
    error ProductNotAvailable();
    error ProductOutOfStock();
    error InsufficientEther();
    error OrderDoesNotExist();
    error CannotCancelOrder();
    error OnlyBuyer();
    error AlreadyDelivered();
    error PayingExcess();
    error RecyclerAlreadyExist();
    error CategoryAlreadyExist();
    error ProductQuantityExceeded();
    error UnauthorizedToCancel();
    error CannotConfirmOrder();
}
