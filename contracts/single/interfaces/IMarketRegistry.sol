//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

interface IMarketRegistry {
    function hasPool(address baseToken) external view returns (bool);
}