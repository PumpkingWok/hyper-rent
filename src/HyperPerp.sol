// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {HyperCoreGateway} from "src/HyperCoreGateway.sol";

contract HyperPerp is HyperCoreGateway {
    // hyper perp id assigned by the factory
    uint256 public immutable HYPER_PERP_ID;
    // NFT hyper perp factory
    IERC721 public immutable HYPER_PERP_FACTORY;

    // Hyperliquid core perp id
    uint32 public immutable CORE_PERP_ID;

    error OnlyOwner();

    constructor(address HyperPerpFactory_, uint256 hyperPerpId_, uint32 corePerpId_) {
        HYPER_PERP_FACTORY = IERC721(HyperPerpFactory_);
        HYPER_PERP_ID = hyperPerpId_;
        CORE_PERP_ID = corePerpId_;
    }

    function limitOrder(bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, EncodedTif encodedTif, uint128 cloid)
        external
        onlyWalletOwner
    {
        _limitOrder(CORE_PERP_ID, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid);
    }

    function sendSpot(address destination, uint64 token, uint64 amount) external onlyWalletOwner {
        _sendSpot(destination, token, amount);
    }

    function getAccountMarginSummary() external view returns (AccountMarginSummary memory) {
        return _accountMarginSummary(CORE_PERP_ID, address(this));
    }

    function getAccountValue() external view returns (int64) {
        return _accountMarginSummary(CORE_PERP_ID, address(this)).accountValue;
    }

    function getAccountRawUsd() external view returns (int64) {
        return _accountMarginSummary(CORE_PERP_ID, address(this)).rawUsd;
    }

    function getPositionSzi() external view returns (int64) {
        return _position2(address(this), CORE_PERP_ID).szi;
    }

    modifier onlyWalletOwner() {
        if (HYPER_PERP_FACTORY.ownerOf(HYPER_PERP_ID) != msg.sender) revert OnlyOwner();
        _;
    }
}
