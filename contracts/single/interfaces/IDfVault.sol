//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IDfVaultStorage} from "./IDfVaultStorage.sol";

interface IDfVault is IDfVaultStorage {
    event InitializedVault(
        address _reader,
        address _dfImplementation,
        uint256 _capacityPerDf,
        uint256 _minInvestmentAmount,
        uint256 _maxInvestmentAmount,
        uint256 _minManagerInvestmentAmount,
        uint256 _maxLeverage,
        address _usdc,
        address _weth,
        address _admin,
        address _treasury
    );
    event NewFundCreated(
        address indexed baseToken,
        uint256 fundraisingPeriod,
        uint256 entryPrice,
        uint256 targetPrice,
        uint256 liquidationPrice,
        uint256 leverage,
        bool tradeDirection,
        address indexed dfAddress,
        address indexed manager,
        bytes32 id
    );
    event DepositIntoFund(address indexed _dfAddress, address indexed investor, uint256 amount);
    event FundraisingClosed(address indexed _dfAddress);
    event FundraisingCloseAndVaultOpened(address indexed _dfAddress, bool _isLimit, uint256 triggerPrice);
    event VaultOpened(address indexed _dfAddress, bool isLimit, uint256 triggerPrice);
    event VaultClosed(
        address indexed _dfAddress, uint256 size, bool isLimit, uint256 triggerPrice, bool closedCompletely
    );
    event OrderUpdated(
        address indexed _dfAddress, uint256 _size, uint256 _triggerPrice, bool _isOpen, bool _triggerAboveThreshold
    );
    event OrderCancelled(address indexed _dfAddress, uint256 _orderIndex, bool _isOpen, uint256 _totalRaised);
    event CreatedPositionAgain(address indexed _dfAddress, bool _isOpen, uint256 _triggerPrice);
    event FeesTransferred(
        address indexed _dfAddress, uint256 _remainingBalance, uint256 _managerFee, uint256 _protocolFee
    );
    event Claimed(address indexed investor, address indexed dfAddress, uint256 amount);
    event VaultLiquidated(address indexed dfAddress);
    event NoFillVaultClosed(address indexed dfAddress);
    event CapacityPerDfChanged(uint256 capacity);
    event MaxInvestmentAmountChanged(uint256 maxAmount);
    event MinInvestmentAmountChanged(uint256 maxAmount);
    event MinManagerInvestmentAmountChanged(uint256 maxAmount);
    event MaxLeverageChanged(uint256 maxLeverage);
    event MinLeverageChanged(uint256 minLeverage);
    event MaxFundraisingPeriodChanged(uint256 maxFundraisingPeriod);
    event ManagerFeeChanged(uint256 managerFee);
    event ProtocolFeeChanged(uint256 protocolFee);
    event DfImplementationChanged(address indexed df);
    event ReaderAddressChanged(address indexed reader);
    event FundDeadlineChanged(address indexed dfAddress, uint256 fundDeadline);
    event MaxDeadlineForPositionChanged(uint256 maxDeadlineForPosition);
    event UsdcAddressChanged(address indexed usdc);
    event WethAddressChanged(address indexed weth);
    event AdminChanged(address indexed admin);
    event TreasuryChanged(address indexed treasury);
    event ReferralCodeChanged(bytes32 referralCode);
    event WithdrawEth(address indexed receiver, uint256 amount);
    event WithdrawToken(address indexed token, address indexed receiver, uint256 amount);
    event WithdrawFromDf(
        address indexed dfAddress, address indexed receiver, bool isEth, address indexed token, uint256 amount
    );
    event DfStatusUpdate(address indexed dfAddress, DfStatus status);
    event DfTotalRaisedUpdate(address indexed dfAddress, uint256 totalRaised);
    event DfRemainingBalanceUpdate(address indexed dfAddress, uint256 remainingBalance);
    event ManagingFundUpdate(address indexed manager, bool isManaging);

    function getUserAmount(address _dfAddress, address _investor) external view returns (uint256);

    function getClaimAmount(address _dfAddress, address _investor) external view returns (uint256);

    function getClaimed(address _dfAddress, address _investor) external view returns (bool);

    function isDistributed(address _dfAddress) external view returns (bool);

    function isClosed(address _dfAddress) external view returns (bool);

    function isOpened(address _dfAddress) external view returns (bool);

    function createNewDf(Df calldata _fund, bytes32 id) external returns (address);

    function depositIntoFund(address _dfAddress, uint256 amount) external;

    function closeFundraising(address _dfAddress) external;

    function closeFundraisingAndOpenPosition(address _dfAddress, bool _isLimit, uint256 _triggerPrice)
        external
        payable;

    function openPosition(address _dfAddress, bool _isLimit, uint256 _triggerPrice) external payable;

    function closePosition(
        address _dfAddress,
        bool _isLimit,
        uint256 _size,
        uint256 _triggerPrice
    ) external payable;

    function claimableAmount(address _dfAddress, address _investor) external view returns (uint256);

    function claim(address _dfAddress) external;

    function closeLiquidatedVault(address _dfAddress) external;

    function cancelVault(address _dfAddress) external;

    function cancelDfByManager(address _dfAddress) external;

    function setCapacityPerDf(uint256 _capacity) external;

    function setMinInvestmentAmount(uint256 _amount) external;

    function setMaxInvestmentAmount(uint256 _amount) external;

    function setMinManagerInvestmentAmount(uint256 _amount) external;

    function setMaxLeverage(uint256 _maxLeverage) external;

    function setMinLeverage(uint256 _minLeverage) external;

    function setManagerFee(uint256 _managerFee) external;

    function setProtocolFee(uint256 _protocolFee) external;

    function setDfImplementation(address _df) external;

    function setReader(address _reader) external;

    function setFundDeadline(address _df, uint256 _fundDeadline) external;

    function setDfStatus(DfStatus) external;

    function setDfTotalRaised(uint256 totalRaised) external;

    function setDfRemainingBalance(uint256 remainingBalance) external;

    function withdrawEth(address receiver, uint256 amount) external;

    function withdrawToken(address token, address receiver, uint256 amount) external;

    function withdrawFromDf(address _dfAddress, address receiver, bool isEth, address token, uint256 amount) external;
}