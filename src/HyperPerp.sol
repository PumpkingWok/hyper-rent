// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";

import {HyperCoreGateway} from "src/HyperCoreGateway.sol";

contract HyperPerp is HyperCoreGateway, Initializable {
    // NFT hyper perp factory
    IERC721 public immutable HYPER_PERP_FACTORY;

    // hyper perp id assigned by the factory
    uint256 public hyperPerpId;
    // Hyperliquid core perp id
    uint32 public corePerpId;

    error OnlyOwner();

    constructor(address hyperPerpFactory_) {
        HYPER_PERP_FACTORY = IERC721(hyperPerpFactory_);
    }

    function initialize(uint256 hyperPerpId_, uint32 corePerpId_) external initializer {
        hyperPerpId = hyperPerpId_;
        corePerpId = corePerpId_;
    }

    function limitOrder(bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, EncodedTif encodedTif, uint128 cloid)
        external
        onlyWalletOwner
    {
        _limitOrder(corePerpId, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid);
    }

    function sendSpot(address destination, uint64 token, uint64 amount) external onlyWalletOwner {
        _sendSpot(destination, token, amount);
    }

    function getAccountMarginSummary() external view returns (AccountMarginSummary memory) {
        return _accountMarginSummary(address(this));
    }

    function getAccountValue() external view returns (int64) {
        return _accountMarginSummary(address(this)).accountValue;
    }

    function getAccountRawUsd() external view returns (int64) {
        return _accountMarginSummary(address(this)).rawUsd;
    }

    function getPositionSzi() external view returns (int64) {
        return _position2(address(this), corePerpId).szi;
    }

    modifier onlyWalletOwner() {
        if (HYPER_PERP_FACTORY.ownerOf(hyperPerpId) != msg.sender) revert OnlyOwner();
        _;
    }
}
