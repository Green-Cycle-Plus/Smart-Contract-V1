// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrow {
    function escrowCounter() external view returns (uint256);
    function createEscrow(address _payee) external payable;
    function releaseEscrow(uint256 escrowId) external;
    function refundEscrow(uint256 escrowId) external;
}
