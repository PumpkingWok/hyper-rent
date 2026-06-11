// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IHyperPerpFactory {
    function perps(uint256 id) external view returns (address);
}
