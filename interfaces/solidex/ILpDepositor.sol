// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;
pragma experimental ABIEncoderV2;

struct Amounts {
    uint256 solid;
    uint256 sex;
}

interface ILpDepositor {
    function deposit(address pool, uint256 amount) external;

    function withdraw(address pool, uint256 amount) external;

    function userBalances(address user, address pool) external view returns (uint256);

    function getReward(address[] calldata pools) external;

    function pendingRewards(
        address account,
        address[] calldata pools)
    external view returns (Amounts[] memory pending);
}