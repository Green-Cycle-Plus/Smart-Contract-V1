// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrow {
    
    function createEscrow(address _payee) external payable  returns (uint256) ;

    function releaseEscrow(uint256 escrowId) external;

    function refundEscrow(uint256 escrowId) external;


}