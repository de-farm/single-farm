//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IDfVaultStorage} from "./IDfVaultStorage.sol";

interface IDfPerp is IDfVaultStorage {
    event FundDeadlineChanged(uint256 newDeadline, address indexed dfAddress);
    event ManagerAddressChanged(address indexed newManager, address indexed dfAddress);
    event ReferralCodeChanged(bytes32 newReferralCode, address indexed dfAddress);
    event ClaimedUSDC(address indexed investor, uint256 claimAmount, uint256 timeOfClaim, address indexed dfAddress);
    event VaultLiquidated(uint256 timeOfLiquidation, address indexed dfAddress);
    event NoFillVaultClosed(uint256 timeOfClose, address indexed dfAddress);
    event TradeDeadlineChanged(uint256 newTradeDeadline, address indexed dfAddress);

    function openPosition() external returns (bool);

    function closePosition() external returns (bool);
    function withdraw(address receiver, bool isEth, address token, uint256 amount) external returns (bool);
}