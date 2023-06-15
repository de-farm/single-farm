// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IReader} from "./interfaces/IReader.sol";
import {IMarketRegistry} from "./interfaces/IMarketRegistry.sol";
import {IBaseToken} from "./interfaces/IBaseToken.sol";

contract Reader is IReader {
    Perp public dex;

    constructor(Perp memory _dex) {
        dex = _dex;
    }

    function getDex() external view override returns (
        address, address, address
    ) {
        return (dex.vault, dex.marketRegistry, dex.clearingHouse);
    }

    function getBaseTokenEligible(address _baseToken) external view override returns (bool) {
        return IMarketRegistry(dex.marketRegistry).hasPool(_baseToken);
    }

    function getPrice(address _baseToken) public view override returns (uint256, uint256) {
        return (IBaseToken(_baseToken).getIndexPrice(0), 1e12);
    }

    function checkPrices(uint256 _entry, uint256 _target, address _baseToken, bool _tradeDirection)
        external
        view
        returns (bool)
    {
        (uint256 price, uint256 denominator) = getPrice(_baseToken);
        uint256 lower = price / (denominator * 10);
        uint256 upper = (price * 10) / denominator;

        if (_tradeDirection) {
            require(lower <= _entry, "entry should be more than lower");
            require(_entry < _target, "entry should be less than target");
            require(_target <= upper, "target should be less than upper");
        } else {
            require(lower <= _target, "target should be more than lower");
            require(_target < _entry, "target should be less than entry");
            require(_entry <= upper, "entry should be less than upper");
        }

        return true;
    }
}