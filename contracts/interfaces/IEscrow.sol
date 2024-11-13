// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrow {
    function createEscrow(address _payee) external payable;
    function releaseEscrow(uint256 escrowId) external;
}
