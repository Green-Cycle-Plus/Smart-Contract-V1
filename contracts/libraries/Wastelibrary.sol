// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library waste {
    error REGISTERED();
    error NOT_REGISTERED();
    error NOT_AVAILABLE();
    error INVALID_ID();
    error INCOMPLETE_REQUEST();
    error LOWER_THAN_MINQUANTITY();
    error NOT_AMONG_OFFERS();
    error ALLREADY_ACCEPTED();
    error NOT_ACCEPTED_YET();
    error ALREADY_COMPLETED();
    error NOT_ASSIGNED();
    error PAYMENT_REQUIRED();
    error TRANSFER_FAILED();
    error ONLY_A_RECYCLER();
    error NOT_AUTHORIZED();
    error RECYCLER_ALREADY_REGISTERED();
    error RECYCLERNOTFOUND();
    error INVALIDLONGITUDE();
    error INVALIDLATITUTUDE();
    error INVALIDOFFERNAME();
    error INVALIDPRICE();
    error INVALIDQUANTITY();
    error INVALIDRECYCLER();
    error OFFERNOTFOUND();
    error INVALIDAMOUNT();
    error REQUESTNOTFOUND();
    error REQUESTALREADYASSIGNED();
    error AMOUNT_LESS_THAN_AMOUNT_VALUED();
    error ALREADY_ACCEPTED();
    error NOT_FOUND();
}
