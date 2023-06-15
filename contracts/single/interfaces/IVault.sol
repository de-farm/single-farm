//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

interface IVault {
    event Deposited(address indexed collateralToken, address indexed trader, uint256 amount);

    event Withdrawn(address indexed collateralToken, address indexed trader, uint256 amount);

    function deposit(address token, uint256 amountX10_D) external;

    function withdraw(address token, uint256 amountX10_D) external;

    function getBalanceByToken(address trader, address token) external view returns (int256);

    function getFreeCollateral(address trader) external view returns (uint256);
    function getFreeCollateralByToken(address trader, address token) external view returns (uint256);
    function getFreeCollateralByRatio(address trader, uint24 ratio) external view returns (int256);

    function getSettlementToken() external view returns (address);

    function decimals() external view returns (uint8);

    function getTotalDebt() external view returns (uint256);

    function getClearingHouseConfig() external view returns (address);

    function getAccountBalance() external view returns (address);

    function getInsuranceFund() external view returns (address);

    function getExchange() external view returns (address);

    function getClearingHouse() external view returns (address);

    function getSettlementTokenValue(address trader) external view returns (int256);

    function getAccountValue(address trader) external view returns (int256);
}