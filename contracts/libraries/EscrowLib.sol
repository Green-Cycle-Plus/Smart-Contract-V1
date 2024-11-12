// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library EscrowLibrary {
    struct Escrow {
        address payer;
        address payee;
        uint256 amount;
        bool isFunded;
        bool isReleased;
        bool isRefunded;
    }

    /// @notice Initializes a new escrow
    /// @param self The escrow struct instance
    /// @param _payer Address of the party funding the escrow
    /// @param _payee Address of the party receiving the escrow funds
    /// @param _amount Amount to be held in escrow
    function initialize(
        Escrow storage self,
        address _payer,
        address _payee,
        uint256 _amount
    ) internal {
        self.payer = _payer;
        self.payee = _payee;
        self.amount = _amount;
        self.isFunded = true;
    }
}