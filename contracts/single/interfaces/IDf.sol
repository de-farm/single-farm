//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IDfVaultStorage} from "./IDfVaultStorage.sol";

interface IDf is IDfVaultStorage {
    event Initialized(address indexed manager, address indexed dfAddress, address indexed vault);

    function initialize(Df calldata _df, address _manager, address _usdc, address _weth, address _reader) external;

    function remainingBalance() external view returns (uint256);
}