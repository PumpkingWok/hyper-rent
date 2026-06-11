// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ICoreWriter} from "src/interfaces/ICoreWriter.sol";

abstract contract HyperCoreGateway {
    enum EncodedTif {
        Alo,
        Gtc,
        Ioc
    }

    struct Position {
        int64 szi;
        uint64 entryNtl;
        int64 isolatedRawUsd;
        uint32 leverage;
        bool isIsolated;
    }

    struct AccountMarginSummary {
        int64 accountValue;
        uint64 marginUsed;
        uint64 ntlPos;
        int64 rawUsd;
    }

    address constant ACCOUNT_MARGIN_SUMMARY_PRECOMPILE_ADDRESS = 0x000000000000000000000000000000000000080F;
    address constant POSITION2_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000813;
    ICoreWriter public constant CORE_WRITER = ICoreWriter(0x3333333333333333333333333333333333333333);

    function _limitOrder(
        uint32 corePerpId,
        bool isBuy,
        uint64 limitPx,
        uint64 sz,
        bool reduceOnly,
        EncodedTif encodedTif,
        uint128 cloid
    ) internal {
        bytes memory encodedAction = abi.encode(corePerpId, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid);
        _execute(encodedAction, 0x01);
    }

    function _sendSpot(address destination, uint64 token, uint64 amount) internal {
        bytes memory encodedAction = abi.encode(destination, token, amount);
        _execute(encodedAction, 0x06);
    }

    function _execute(bytes memory encodedAction, bytes1 actionId) internal {
        bytes memory data = new bytes(4 + encodedAction.length);
        data[0] = 0x01;
        data[1] = 0x00;
        data[2] = 0x00;
        data[3] = actionId;
        for (uint256 i = 0; i < encodedAction.length; i++) {
            data[4 + i] = encodedAction[i];
        }
        CORE_WRITER.sendRawAction(data);
    }

    function _accountMarginSummary(uint32 perpDexIndex, address user)
        internal
        view
        returns (AccountMarginSummary memory)
    {
        bool success;
        bytes memory result;
        (success, result) = ACCOUNT_MARGIN_SUMMARY_PRECOMPILE_ADDRESS.staticcall(abi.encode(perpDexIndex, user));
        require(success, "Account margin summary precompile call failed");
        return abi.decode(result, (AccountMarginSummary));
    }

    function _position2(address user, uint32 perp) internal view returns (Position memory) {
        bool success;
        bytes memory result;
        (success, result) = POSITION2_PRECOMPILE_ADDRESS.staticcall(abi.encode(user, perp));
        require(success, "Position precompile call failed");
        return abi.decode(result, (Position));
    }
}
