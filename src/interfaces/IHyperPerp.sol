// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IHyperPerp {
    function sendSpot(address destination, uint64 token, uint64 amount) external;

    function getAccountValue() external view returns (int64);

    function getAccountRawUsd() external view returns (int64);

    function getPositionSzi() external view returns (int64);
}
