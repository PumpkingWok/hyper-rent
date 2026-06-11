// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/access/Ownable2Step.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";

import {HyperPerp} from "./HyperPerp.sol";

/// @notice HyperPerp factory
/// @author PumpkingWok
contract HyperPerpFactory is Ownable2Step, ERC721 {
    /// @dev HyperPerp implementation contract
    address public immutable HYPER_PERP;

    /// @dev Next id to mint
    uint256 public hyperPerpId;

    /// @dev core perp id => enabled
    mapping(uint32 => bool) public corePerpIds;

    /// @dev module address => enabled/disabled
    //mapping(address => bool) public modules;

    /// @dev walletId => hyperWallet contract
    mapping(uint256 => address) public perps;

    error PerpIdNotEnabled();

    /// @dev Emitted when a system address is set
    event SetSystemAddress(address token, address systemAddress);

    /// @dev Emitted when a core perp id is toggled
    event ToggleCorePerpId(uint32 corePerpId, bool status);

    /// @dev Emitted when a new wallet is deployed
    event HyperPerpCreated(address user, uint256 hyperPerpId, address hyperPerp);

    constructor(address owner_) Ownable(owner_) ERC721("HyperPerp", "HP") {
        HYPER_PERP = address(new HyperPerp(address(this)));
    }

    /**
     * @notice Creates a new HyperPerp
     * @dev Deploys a new clone, initializes it, and mints an NFT to the caller
     * @param corePerpId Perp id at core
     * @return hyperPerp The address of the newly created hyperPerp
     */
    function createHyperPerp(uint32 corePerpId) external returns (address hyperPerp) {
        // check if the perp id is enabled
        if (!corePerpIds[corePerpId]) revert PerpIdNotEnabled();

        // deploy a new account contract
        hyperPerp = Clones.clone(HYPER_PERP);
        HyperPerp(payable(hyperPerp)).initialize(hyperPerpId, corePerpId);

        // mint an NFT to the user
        _mint(msg.sender, hyperPerpId);

        perps[hyperPerpId] = hyperPerp;

        emit HyperPerpCreated(msg.sender, hyperPerpId++, hyperPerp);
    }

    /**
     * @notice Enable/Disable core perp id
     * @param corePerpId Core Perp Id to toggle
     */
    function toggleCorePerpId(uint32 corePerpId) external onlyOwner {
        corePerpIds[corePerpId] = !corePerpIds[corePerpId];

        emit ToggleCorePerpId(corePerpId, corePerpIds[corePerpId]);
    }
}
