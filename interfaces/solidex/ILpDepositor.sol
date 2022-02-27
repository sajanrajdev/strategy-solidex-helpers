// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

interface ILpDepositor {
    function deposit(address pool, uint256 amount) external;

    function withdraw(address pool, uint256 amount) external;

    function userBalances(address user, address pool) external view returns (uint256);

    function getReward(address[1] calldata pools) external;
}