// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDf} from "./interfaces/IDf.sol";
import {IDfPerp} from "./interfaces/IDfPerp.sol";
import {IDfVault} from "./interfaces/IDfVault.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IReader} from "./interfaces/IReader.sol";

error ZeroAddress();
error ZeroAmount();
error ZeroTokenBalance();
error NoAccess(address desired, address given);
error StillFundraising(uint256 desired, uint256 given);
error InvalidChainId(uint256 desired, uint256 given);
error BelowMin(uint256 min, uint256 given);
error AboveMax(uint256 max, uint256 given);

error NoManagerFund(address manager);
error FundExists(address fund);
error NoBaseToken(address token);
/// Direction: 0 = long, 1 = short.
error NotEligible(uint256 entry, uint256 exit, bool direction);
error AlreadyOpened();
error MismatchStatus(IDfVault.DfStatus given);
error CantOpen();
error CantClose();
error NotOpened();
error NotFinalised();
error NoCloseActions();
error OpenPosition();
error NoOpenPositions();

contract DfVault is IDfVault, Pausable, Ownable {
    address private USDC;
    address private WETH;

    address public admin;
    address public treasury;
    address public dfImplementation;

    IReader public reader;

    // max amount which can be fundraised by the manager per df
    uint256 public capacityPerDf;
    // min investment amount per investor per df
    uint256 public minInvestmentAmount;
    // max investment amount per investor per df
    uint256 public maxInvestmentAmount;
    // min investment amount of manager per df
    uint256 public minManagerInvestmentAmount;
    // percentage of fees from the profits of the df to the manager
    uint256 public managerFee;
    // percentage of fees from the profits of the df to the protocol
    uint256 public protocolFee;
    // max leverage which can be used by the manager when creating an df
    uint256 public maxLeverage;
    // min leverage which can be used by the manager when creating an df
    uint256 public minLeverage;
    // max fundraising period which can be used by the manager to raise funds
    uint256 public maxFundraisingPeriod;
    // the max time a trade can be open
    uint256 public maxDeadlineForPosition;
    // referralCode used for opening a position on the dex
    bytes32 public referralCode;

    mapping(address => DfInfo) public dfInfo;
    mapping(address => uint256) public actualTotalRaised;
    // mapping of df and the manager fees
    mapping(address => uint256) public managerFees;
    // mapping of df and the protocol fees
    mapping(address => uint256) public protocolFees;

    constructor(
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
    ) {
        if (_reader == address(0)) revert ZeroAddress();
        if (_dfImplementation == address(0)) revert ZeroAddress();
        if (_usdc == address(0)) revert ZeroAddress();
        if (_weth == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        reader = IReader(_reader);

        dfImplementation = _dfImplementation;
        capacityPerDf = _capacityPerDf;
        minInvestmentAmount = _minInvestmentAmount;
        maxInvestmentAmount = _maxInvestmentAmount;

        if (_minManagerInvestmentAmount < _minInvestmentAmount) revert BelowMin(_minInvestmentAmount, _minManagerInvestmentAmount);
        if (_minManagerInvestmentAmount > _maxInvestmentAmount) revert AboveMax(_maxInvestmentAmount, _minManagerInvestmentAmount);
        minManagerInvestmentAmount = _minManagerInvestmentAmount;

        minLeverage = 1e6;
        maxLeverage = _maxLeverage;
        USDC = _usdc;
        WETH = _weth;
        managerFee = 15e18;
        protocolFee = 5e18;
        maxFundraisingPeriod = 1 weeks;
        admin = _admin;
        treasury = _treasury;
        maxDeadlineForPosition = 2592000; // 30 days

        emit InitializedVault(
            _reader,
            _dfImplementation,
            _capacityPerDf,
            _minInvestmentAmount,
            _maxInvestmentAmount,
            _minManagerInvestmentAmount,
            _maxLeverage,
            _usdc,
            _weth,
            _admin,
            _treasury
            );
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NoAccess(admin, msg.sender);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW
    //////////////////////////////////////////////////////////////*/
    function getUserAmount(address _dfAddress, address _investor) external view override returns (uint256) {
        DfInfo storage _df = dfInfo[_dfAddress];
        return _df.userAmount[_investor];
    }

    function getClaimAmount(address _dfAddress, address _investor) external view override returns (uint256) {
        DfInfo storage _df = dfInfo[_dfAddress];
        return _df.claimAmount[_investor];
    }

    function getClaimed(address _dfAddress, address _investor) external view override returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        return _df.claimed[_investor];
    }

    function getDfInfo(address _dfAddress)
        external
        view
        returns (address, address, uint256, uint256, uint256, uint256, DfStatus)
    {
        DfInfo storage _df = dfInfo[_dfAddress];

        return (
            _df.dfAddress,
            _df.manager,
            _df.totalRaised,
            _df.remainingAmountAfterClose,
            _df.endTime,
            _df.fundDeadline,
            _df.status
        );
    }

    function isDistributed(address _dfAddress) external view returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        if(_df.status == DfStatus.DISTRIBUTED) return true;
        else return false;
    }

    function isClosed(address _dfAddress) external view returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        if(_df.status == DfStatus.CLOSED) return true;
        else return false;
    }

    function isOpened(address _dfAddress) external view returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        if(_df.status == DfStatus.OPENED) return true;
        else return false;
    }

    function isCancelled(address _dfAddress) external view returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        if(_df.status == DfStatus.CANCELLED) return true;
        else return false;
    }

    function isNotOpened(address _dfAddress) external view returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        if(_df.status == DfStatus.NOT_OPENED) return true;
        else return false;
    }

    function isLiquidated(address _dfAddress) external view returns (bool) {
        DfInfo storage _df = dfInfo[_dfAddress];
        if(_df.status == DfStatus.LIQUIDATED) return true;
        else return false;
    }

    function getStatusOfDf(address _dfAddress) external view returns (DfStatus) {
        DfInfo storage _df = dfInfo[_dfAddress];
        return _df.status;
    }

    function getPnl(address _dfAddress)
        external
        view
        returns (
            uint256 mFee,
            uint256 pFee,
            int256 pnlBeforeFees,
            int256 pnlAfterFees,
            bool distributed
        )
    {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (_df.status == DfStatus.DISTRIBUTED) distributed = true;
        mFee = managerFees[_dfAddress];
        pFee = protocolFees[_dfAddress];
        pnlBeforeFees = int256(_df.remainingAmountAfterClose + mFee + pFee) - int256(actualTotalRaised[_dfAddress]);
        pnlAfterFees = int256(_df.remainingAmountAfterClose) - int256(actualTotalRaised[_dfAddress]);
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createNewDf(Df calldata _df, bytes32 _id) external override whenNotPaused returns (address dfAddress) {
        if (_df.fundraisingPeriod < 15 minutes) revert BelowMin(15 minutes, _df.fundraisingPeriod);
        if (_df.fundraisingPeriod > maxFundraisingPeriod) {
            revert AboveMax(maxFundraisingPeriod, _df.fundraisingPeriod);
        }
        if (_df.leverage < minLeverage) revert BelowMin(minLeverage, _df.leverage);
        if (_df.leverage > maxLeverage) revert AboveMax(maxLeverage, _df.leverage);

        dfAddress = Clones.clone(dfImplementation);
        IDf(dfAddress).initialize(_df, msg.sender, USDC, WETH, address(reader));

        dfInfo[dfAddress].dfAddress = dfAddress;
        dfInfo[dfAddress].manager = msg.sender;
        dfInfo[dfAddress].endTime = block.timestamp + _df.fundraisingPeriod;
        dfInfo[dfAddress].fundDeadline = 72 hours;

        emit NewFundCreated(
            _df.baseToken,
            _df.fundraisingPeriod,
            _df.entryPrice,
            _df.targetPrice,
            _df.liquidationPrice,
            _df.leverage,
            _df.tradeDirection,
            dfAddress,
            msg.sender,
            _id
        );
    }

    function depositIntoFund(address _dfAddress, uint256 amount) external override whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (block.timestamp > _df.endTime) revert AboveMax(_df.endTime, block.timestamp);
        if (amount < minInvestmentAmount) revert BelowMin(minInvestmentAmount, amount);
        if (_df.userAmount[msg.sender] + amount > maxInvestmentAmount) {
            revert AboveMax(maxInvestmentAmount, _df.userAmount[msg.sender] + amount);
        }
        if (_df.status != DfStatus.NOT_OPENED) revert AlreadyOpened();
        if (_df.totalRaised + amount > capacityPerDf) revert AboveMax(capacityPerDf, _df.totalRaised + amount);
        //
        if (
            _df.userAmount[_df.manager] < minManagerInvestmentAmount &&
            msg.sender != _df.manager
        ) revert NoManagerFund(_df.manager);

        _df.totalRaised += amount;
        _df.userAmount[msg.sender] += amount;
        actualTotalRaised[_dfAddress] += amount;

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        emit DepositIntoFund(_dfAddress, msg.sender, amount);
    }

    function closeFundraising(address _dfAddress) external override whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (_df.manager != msg.sender) revert NoAccess(_df.manager, msg.sender);
        if (_df.status != DfStatus.NOT_OPENED) revert AlreadyOpened();
        if (_df.totalRaised < 1) revert ZeroAmount();
        if (block.timestamp < _df.endTime) revert CantClose();

        _df.endTime = block.timestamp;

        emit FundraisingClosed(_dfAddress);
    }

    function closeFundraisingAndOpenPosition(address _dfAddress, bool _isLimit, uint256 _triggerPrice)
        external
        payable
        override
        whenNotPaused
    {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (_df.manager != msg.sender) revert NoAccess(_df.manager, msg.sender);
        if (_df.status != DfStatus.NOT_OPENED) revert AlreadyOpened();
        if (block.timestamp < _df.endTime) revert CantClose();
        if (_df.totalRaised < 1) revert ZeroAmount();

        _df.status = DfStatus.OPENED;
        _df.endTime = block.timestamp;

        IERC20(USDC).transfer(_dfAddress, _df.totalRaised);

        if (block.chainid == 10 || block.chainid ==  420) {
            if (!IDfPerp(_dfAddress).openPosition()) revert CantOpen();
        }

        emit FundraisingCloseAndVaultOpened(_dfAddress, _isLimit, _triggerPrice);
    }

    function openPosition(address _dfAddress, bool _isLimit, uint256 _triggerPrice)
        external
        payable
        override
        whenNotPaused
    {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (msg.sender != _df.manager) revert NoAccess(_df.manager, msg.sender);
        if (_df.endTime > block.timestamp) revert StillFundraising(_df.endTime, block.timestamp);
        if (_df.status != DfStatus.NOT_OPENED) revert AlreadyOpened();
        if (_df.totalRaised < 1) revert ZeroAmount();

        _df.status = DfStatus.OPENED;

        IERC20(USDC).transfer(_dfAddress, _df.totalRaised);

        if (block.chainid == 10 || block.chainid ==  420) {
            if (!IDfPerp(_dfAddress).openPosition()) revert CantOpen();
        }

        emit VaultOpened(_dfAddress, _isLimit, _triggerPrice);
    }

    function closePosition(
        address _dfAddress,
        bool _isLimit,
        uint256 _size,
        uint256 _triggerPrice
    ) external payable override whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (msg.sender != _df.manager && msg.sender != admin) revert NoAccess(_df.manager, msg.sender);
        if (_df.status != DfStatus.OPENED) revert NoOpenPositions();

        bool closed;
        if (block.chainid == 10 || block.chainid ==  420) {
            if (!IDfPerp(_dfAddress).closePosition()) revert CantClose();
            closed = true;

            _df.status = DfStatus.DISTRIBUTED;
        }

        emit VaultClosed(_dfAddress, _size, _isLimit, _triggerPrice, closed);
    }

    function claimableAmount(address _dfAddress, address _investor) public view override returns (uint256 amount) {
        DfInfo storage _df = dfInfo[_dfAddress];

        if (_df.claimed[_investor] || _df.status == DfStatus.OPENED) {
            amount = 0;
        } else if (_df.status == DfStatus.CANCELLED || _df.status == DfStatus.NOT_OPENED) {
            amount = (_df.totalRaised * _df.userAmount[_investor] * 1e18) / (actualTotalRaised[_dfAddress] * 1e18);
        } else if (_df.status == DfStatus.DISTRIBUTED) {
            amount = (_df.remainingAmountAfterClose * _df.userAmount[_investor] * 1e18) / (actualTotalRaised[_dfAddress] * 1e18);
        } else {
            amount = 0;
        }
    }

    function claim(address _dfAddress) external override whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (_df.status != DfStatus.DISTRIBUTED && _df.status != DfStatus.CANCELLED) revert NotFinalised();

        uint256 amount = claimableAmount(_dfAddress, msg.sender);
        if (amount < 1) revert ZeroTokenBalance();

        _df.claimed[msg.sender] = true;
        _df.claimAmount[msg.sender] = amount;

        IERC20(USDC).transfer(msg.sender, amount);
        emit Claimed(msg.sender, _dfAddress, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function closeLiquidatedVault(address _dfAddress) external override onlyAdmin whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (_df.status != DfStatus.OPENED) revert NotOpened();
        _df.status = DfStatus.LIQUIDATED;

        emit VaultLiquidated(_dfAddress);
    }

    function cancelVault(address _dfAddress) external override onlyAdmin whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (_df.status != DfStatus.NOT_OPENED) revert OpenPosition();
        if (_df.totalRaised == 0) {
            if (block.timestamp <= _df.endTime) revert BelowMin(_df.endTime, block.timestamp);
        } else {
            if (block.timestamp <= _df.endTime + _df.fundDeadline) revert BelowMin(_df.endTime, block.timestamp);
        }
        _df.status = DfStatus.CANCELLED;

        emit NoFillVaultClosed(_dfAddress);
    }

    function cancelDfByManager(address _dfAddress) external override whenNotPaused {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (msg.sender != _df.manager) revert NoAccess(_df.manager, msg.sender);
        if (_df.status != DfStatus.NOT_OPENED) revert OpenPosition();
        if (block.timestamp > _df.endTime + _df.fundDeadline) revert CantClose();

        _df.fundDeadline = 0;
        _df.endTime = 0;
        _df.status = DfStatus.CANCELLED;

        emit NoFillVaultClosed(_dfAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setCapacityPerDf(uint256 _capacity) external override onlyOwner whenNotPaused {
        if (_capacity < 1) revert ZeroAmount();
        capacityPerDf = _capacity;
        emit CapacityPerDfChanged(_capacity);
    }

    function setMinInvestmentAmount(uint256 _amount) external override onlyOwner whenNotPaused {
        if (_amount < 1) revert ZeroAmount();
        minInvestmentAmount = _amount;
        emit MinInvestmentAmountChanged(_amount);
    }

    function setMaxInvestmentAmount(uint256 _amount) external override onlyOwner whenNotPaused {
        if (_amount <= minInvestmentAmount) revert BelowMin(minInvestmentAmount, _amount);
        maxInvestmentAmount = _amount;
        emit MaxInvestmentAmountChanged(_amount);
    }

    function setMinManagerInvestmentAmount(uint256 _amount) external override onlyOwner whenNotPaused {
        if (_amount < 1) revert ZeroAmount();
        if (_amount < minInvestmentAmount) revert BelowMin(minInvestmentAmount, _amount);
        if (_amount > maxInvestmentAmount) revert AboveMax(maxInvestmentAmount, _amount);
        minManagerInvestmentAmount = _amount;
        emit MinManagerInvestmentAmountChanged(_amount);
    }

    function setMaxLeverage(uint256 _maxLeverage) external override onlyOwner whenNotPaused {
        if (_maxLeverage <= 1e6) revert AboveMax(1e6, _maxLeverage);
        maxLeverage = _maxLeverage;
        emit MaxLeverageChanged(_maxLeverage);
    }

    function setMinLeverage(uint256 _minLeverage) external override onlyOwner whenNotPaused {
        if (_minLeverage < 1e6) revert BelowMin(1e16, _minLeverage);
        minLeverage = _minLeverage;
        emit MinLeverageChanged(_minLeverage);
    }

    function setMaxFundraisingPeriod(uint256 _maxFundraisingPeriod) external onlyOwner whenNotPaused {
        if (_maxFundraisingPeriod < 15 minutes) revert BelowMin(15 minutes, _maxFundraisingPeriod);
        maxFundraisingPeriod = _maxFundraisingPeriod;
        emit MaxFundraisingPeriodChanged(_maxFundraisingPeriod);
    }

    function setMaxDeadlineForPosition(uint256 _maxDeadlineForPosition) external onlyOwner whenNotPaused {
        if(_maxDeadlineForPosition < 1 days) revert BelowMin(1 days, _maxDeadlineForPosition);
        maxDeadlineForPosition = _maxDeadlineForPosition;
        emit MaxDeadlineForPositionChanged(_maxDeadlineForPosition);
    }

    function setManagerFee(uint256 newManagerFee) external override onlyOwner whenNotPaused {
        managerFee = newManagerFee;
        emit ManagerFeeChanged(newManagerFee);
    }

    function setProtocolFee(uint256 newProtocolFee) external override onlyOwner whenNotPaused {
        protocolFee = newProtocolFee;
        emit ProtocolFeeChanged(newProtocolFee);
    }

    function setDfImplementation(address df) external override onlyOwner {
        dfImplementation = df;
        emit DfImplementationChanged(df);
    }

    function setReader(address _reader) external override onlyOwner {
        reader = IReader(_reader);
        emit ReaderAddressChanged(_reader);
    }

    function setFundDeadline(address _dfAddress, uint256 newFundDeadline) external override {
        DfInfo storage _df = dfInfo[_dfAddress];
        if (msg.sender != _df.manager && msg.sender != owner()) revert NoAccess(_df.manager, msg.sender);
        if (newFundDeadline > 72 hours) revert AboveMax(72 hours, newFundDeadline);
        _df.fundDeadline = newFundDeadline;
        emit FundDeadlineChanged(_dfAddress, newFundDeadline);
    }

    function setUsdc(address _usdc) external onlyOwner {
        if (_usdc == address(0)) revert ZeroAddress();
        USDC = _usdc;
        emit UsdcAddressChanged(_usdc);
    }

    function setWeth(address _weth) external onlyOwner {
        if (_weth == address(0)) revert ZeroAddress();
        WETH = _weth;
        emit WethAddressChanged(_weth);
    }

    function setAdmin(address _admin) external onlyOwner {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        emit AdminChanged(_admin);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }

    function setReferralCode(bytes32 _referralCode) external onlyOwner {
        referralCode = _referralCode;
        emit ReferralCodeChanged(_referralCode);
    }

    function setDfStatus(DfStatus _status) external override {
        DfInfo storage _df = dfInfo[msg.sender];
        if(_df.dfAddress != msg.sender) revert ZeroAddress();
        _df.status = _status;
        emit DfStatusUpdate(msg.sender, _status);
    }

    function setDfTotalRaised(uint256 _totalRaised) external override {
        DfInfo storage _df = dfInfo[msg.sender];
        if(_df.dfAddress != msg.sender) revert ZeroAddress();
        _df.totalRaised = _totalRaised;
        emit DfTotalRaisedUpdate(msg.sender, _totalRaised);
    }

    function setDfRemainingBalance(uint256 _remainingBalance) external override {
        DfInfo storage _df = dfInfo[msg.sender];
        if(_df.dfAddress != msg.sender) revert ZeroAddress();
        _df.remainingAmountAfterClose = _remainingBalance;
        emit DfRemainingBalanceUpdate(msg.sender, _remainingBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function withdrawEth(address receiver, uint256 amount) external override onlyOwner {
        if (receiver == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if(amount > balance) revert AboveMax(balance, amount);
        payable(receiver).transfer(amount);
        emit WithdrawEth(receiver, amount);
    }

    function withdrawToken(address token, address receiver, uint256 amount) external override onlyOwner {
        if (receiver == address(0)) revert ZeroAddress();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if(amount > balance) revert AboveMax(balance, amount);
        IERC20(token).transfer(receiver, amount);
        emit WithdrawToken(token, receiver, amount);
    }

    function withdrawFromDf(
        address _dfAddress,
        address receiver,
        bool isEth,
        address token,
        uint256 amount
    )
        external
        override
        onlyOwner
    {
        if (receiver == address(0)) revert ZeroAddress();
        uint256 balance;
        if (isEth) {
            balance = address(_dfAddress).balance;
        } else {
            balance = IERC20(token).balanceOf(_dfAddress);
        }
        if(amount > balance) revert AboveMax(balance, amount);

        IDfPerp(_dfAddress).withdraw(receiver, isEth, token, amount);

        emit WithdrawFromDf(_dfAddress, receiver, isEth, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          PAUSE/UNPAUSE
    //////////////////////////////////////////////////////////////*/
    function pause() public onlyAdmin whenNotPaused {
        _pause();
    }

    function unpause() public onlyAdmin whenPaused {
        _unpause();
    }
}