//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

interface IClearingHouse {
    struct OpenPositionParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        bytes32 referralCode;
    }

    struct ClosePositionParams {
        address baseToken;
        uint160 sqrtPriceLimitX96;
        uint256 oppositeAmountBound;
        uint256 deadline;
        bytes32 referralCode;
    }

    function openPosition(OpenPositionParams memory params) external returns (uint256 deltaBase, uint256 deltaQuote);

    function closePosition(ClosePositionParams calldata params) external returns (uint256 deltaBase, uint256 deltaQuote);

    function getAccountValue(address trader) external view returns (int256);

    function getPositionSize(address trader, address baseToken) external view returns (int256);

    function getPositionValue(address trader, address baseToken) external view returns (int256);

    function getOpenNotional(address trader, address baseToken) external view returns (int256);

    function getOwedRealizedPnl(address trader) external view returns (int256);

    function getTotalInitialMarginRequirement(address trader) external view returns (uint256);

    function getNetQuoteBalance(address trader) external view returns (int256);

    function getTotalUnrealizedPnl(address trader) external view returns (int256);
}