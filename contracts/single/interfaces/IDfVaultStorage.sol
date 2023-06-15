// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IDfVaultStorage {
    /// @notice Enum to describe the status of the vault
    /// @dev NOT_OPENED - Not open
    /// @dev OPENED - opened position
    /// @dev CLOSED - closed position
    /// @dev LIQUIDATED - liquidated position
    /// @dev CANCELLED - did not start due to deadline reached
    /// @dev DISTRIBUTED - distributed fees
    enum DfStatus {
        NOT_OPENED,
        OPENED,
        CLOSED,
        LIQUIDATED,
        CANCELLED,
        DISTRIBUTED
    }

    struct Dex {
        address vault;
        address marketRegistry; // market address
        address clearingHouse;
    }

    struct Df {
        address baseToken;
        bool tradeDirection; // Long/Short
        uint256 fundraisingPeriod;
        uint256 entryPrice;
        uint256 targetPrice;
        uint256 liquidationPrice;
        uint256 leverage;
    }

    struct DfInfo {
        address dfAddress;
        address manager;
        uint256 totalRaised;
        uint256 remainingAmountAfterClose;
        uint256 endTime;
        uint256 fundDeadline;
        DfStatus status;
        mapping(address => uint256) userAmount;
        mapping(address => uint256) claimAmount;
        mapping(address => bool) claimed;
    }
}
