// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library EscrowLibrary {
    enum PaymentPlatform {
        WASTE_MANAGER,
        MARKETPLACE
    }

    // escrow struct
    struct Escrow {
        address payer;
        bool isFunded;
        address payee;
        bool isReleased;
        address refundAddress;
        bool isRefunded;
        PaymentPlatform platform;
        uint256 amount;
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
        uint256 _amount,
        address _recyclerAddress,
        PaymentPlatform _platform
    ) internal {
        self.payer = _payer;
        self.payee = _payee;
        self.amount = _amount;
        self.isFunded = true;
        self.platform = _platform;
        self.refundAddress =_recyclerAddress;
    }
}
