// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title EscrowContract - Handles the creation, release, and refund of escrow payments
/// @notice This contract is used for holding funds securely until waste collection is confirmed
/// @dev Uses libraries for reusable code, custom errors for validation, and NatSpec for documentation

import './libraries/EscrowLib.sol';

contract EscrowContract {
    using EscrowLibrary for EscrowLibrary.Escrow;

    /// Custom errors for validation to save gas
    error Unauthorized();
    error InvalidAmount();
    error AlreadyFunded();
    error AlreadyReleased();
    error AlreadyRefunded();
    error NotFunded();

    // state variables
    mapping(uint256 => EscrowLibrary.Escrow) public escrows;
    uint256 public escrowCounter;

    // events
    event EscrowCreated(uint256 indexed escrowId, address indexed payer, address indexed payee, uint256 amount);
    event EscrowReleased(uint256 indexed escrowId);
    event EscrowRefunded(uint256 indexed escrowId);

    /// @notice Creates a new escrow and holds payment from the recycler upon accepting a user's waste pickup(collection) request
    /// @param _payee Address of the payee (collector)
    function createEscrow(address _payee) external payable {
        if (msg.value == 0) revert InvalidAmount();

        uint256 escrowId = ++escrowCounter;
        EscrowLibrary.Escrow storage newEscrow = escrows[escrowId];
        newEscrow.initialize(msg.sender, _payee, msg.value);

        emit EscrowCreated(escrowId, msg.sender, _payee, msg.value);
    }

    /// @notice Releases funds to the user after the collector(recycler) confirms collection
    /// @param escrowId The ID of the escrow to release
    function releaseEscrow(uint256 escrowId) external {
        EscrowLibrary.Escrow storage escrow = escrows[escrowId];

        if (msg.sender != escrow.payer && msg.sender != escrow.payee) revert Unauthorized();
        if (!escrow.isFunded) revert NotFunded();
        if (escrow.isReleased) revert AlreadyReleased();

        escrow.isReleased = true;
        payable(escrow.payee).transfer(escrow.amount);

        emit EscrowReleased(escrowId);
    }

    /// @notice Allows for refunds in case of collection failure or disputes
    /// @param escrowId The ID of the escrow to refund
    function refundEscrow(uint256 escrowId) external {
        EscrowLibrary.Escrow storage escrow = escrows[escrowId];

        if (msg.sender != escrow.payer) revert Unauthorized();
        if (!escrow.isFunded) revert NotFunded();
        if (escrow.isReleased) revert AlreadyReleased();
        if (escrow.isRefunded) revert AlreadyRefunded();

        escrow.isRefunded = true;
        payable(escrow.payer).transfer(escrow.amount);

        emit EscrowRefunded(escrowId);
    }
}
