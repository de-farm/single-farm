// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {DfVault} from "./DfVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDf} from "./interfaces/IDf.sol";
import {IDfPerp} from "./interfaces/IDfPerp.sol";
import {IBaseToken} from "./interfaces/IBaseToken.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IClearingHouse} from "./interfaces/IClearingHouse.sol";
import {IReader} from "./interfaces/IReader.sol";

contract Df is IDf, IDfPerp {
    address private USDC;
    address private WETH;

    bool private calledInitialize;
    bool private calledOpen;

    address public manager;

    Df public df;
    DfVault public vault;
    IReader public reader;

    bytes32 public referralCode;

    uint256 public remainingBalance;
    uint256 public managerFee;
    uint256 public protocolFee;

    modifier initOnce() {
        require(!calledInitialize, "can only initialize once");
        calledInitialize = true;
        _;
    }

    modifier onlyVault() {
        require(msg.sender == address(vault), "onlyVault");
        _;
    }

    modifier openOnce() {
        require(!calledOpen, "can only open once");
        calledOpen = true;
        _;
    }

    function initialize(Df calldata _df, address _manager, address _usdc, address _weth, address _reader)
        external
        override
        initOnce
    {
        df = _df;
        manager = _manager;
        vault = DfVault(msg.sender);
        USDC = _usdc;
        WETH = _weth;
        reader = IReader(_reader);
        emit Initialized(_manager, address(this), msg.sender);
    }

    function openPosition() external override onlyVault openOnce returns (bool) {
        Df memory _df = df;
        (address dexVault,, address dexClearingHouse) = reader.getDex();

        (,, uint256 _totalRaised,,,,) = vault.dfInfo(address(this));

        IERC20(USDC).approve(dexVault, _totalRaised);
        IVault(dexVault).deposit(USDC, _totalRaised);

        if (_df.tradeDirection) { // long
            IClearingHouse(dexClearingHouse).openPosition(
                IClearingHouse.OpenPositionParams({
                    baseToken: _df.baseToken,
                    isBaseToQuote: !_df.tradeDirection,
                    isExactInput: true,
                    amount: _totalRaised * _df.leverage / vault.minLeverage()  * 1e12,
                    oppositeAmountBound: 0,
                    deadline: block.timestamp + 900,
                    sqrtPriceLimitX96: 0,
                    referralCode: referralCode
                })
            );
        } else { // short
            IClearingHouse(dexClearingHouse).openPosition(
                IClearingHouse.OpenPositionParams({
                    baseToken: _df.baseToken,
                    isBaseToQuote: !_df.tradeDirection,
                    isExactInput: false,
                    amount: _totalRaised * _df.leverage / vault.minLeverage() * 1e12,
                    oppositeAmountBound: 0,
                    deadline: block.timestamp + 900,
                    sqrtPriceLimitX96: 0,
                    referralCode: referralCode
                })
            );
        }
        return true;
    }

    function closePosition() external override onlyVault returns (bool) {
        Df memory _df = df;
        (address dexVault,, address dexClearingHouse) = reader.getDex();

        IClearingHouse(dexClearingHouse).closePosition(
            IClearingHouse.ClosePositionParams({
                baseToken: _df.baseToken,
                sqrtPriceLimitX96: 0,
                oppositeAmountBound: 0,
                deadline: block.timestamp + 900,
                referralCode: referralCode
            })
        );

        uint256 collateralBalance = IVault(dexVault).getFreeCollateralByToken(address(this), USDC);
        IVault(dexVault).withdraw(USDC, collateralBalance);
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));

        uint256 profits;

        (,, uint256 _totalRaised,,,,) = vault.dfInfo(address(this));

        if (usdcBalance > _totalRaised) {
            profits = usdcBalance - _totalRaised;
            managerFee = (profits * vault.managerFee()) / 100e18;
            protocolFee = (profits * vault.protocolFee()) / 100e18;

            IERC20(USDC).transfer(manager, managerFee);
            IERC20(USDC).transfer(vault.owner(), protocolFee);

            remainingBalance = IERC20(USDC).balanceOf(address(this));
        } else {
            remainingBalance = usdcBalance;
        }

        vault.setDfRemainingBalance(remainingBalance);

        IERC20(USDC).transfer(address(vault), remainingBalance);
        return true;
    }

    function withdraw(address receiver, bool isEth, address token, uint256 amount) external override onlyVault returns (bool) {
        if(isEth) {
            payable(receiver).transfer(amount);
        }
        else {
            IERC20(token).transfer(receiver, amount);
        }

        return true;
    }
}