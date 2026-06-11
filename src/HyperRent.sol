// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import "openzeppelin/access/Ownable2Step.sol";

import {IHyperPerpFactory} from "src/interfaces/IHyperPerpFactory.sol";
import {IHyperPerp} from "src/interfaces/IHyperPerp.sol";

// Create perp rent auction
contract HyperRent is Ownable2Step, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct Rent {
        address creator;
        address renter;
        uint256 hyperPerpId;
        uint256 duration;
        uint256 startTime;
        uint256 price;
        uint256 expiry;
        int64 initialValue;
        int64 initialRawUsd;
    }

    uint256 public constant BASE_FEE = 10_000;
    uint256 public rentFee = 50; // 0.5%
    uint256 public feeAccrued;

    uint256 public rentId;

    mapping(uint256 => Rent) public rents;

    IERC20 public immutable RENT_TOKEN;
    IERC721 public immutable WALLET_FACTORY;
    address public immutable RENT_TOKEN_SA;
    uint64 public constant RENT_TOKEN_CORE_ID = 0; // USDC

    error EmptyPosition();
    error FeeTooHigh();
    error InvalidRentId();
    error OngoingRent();
    error RentNotExpiryYet();
    error RentNotStartedYet();
    error RentExpired();
    error ZeroAddress();

    event RentAuctionCreated(address indexed creator, uint256 rentId);
    event RentAuctionAccepted(address indexed renter, uint256 rentId);

    constructor(address walletFactory_, address rentToken_, address rentTokenSA_) Ownable(msg.sender) {
        WALLET_FACTORY = IERC721(walletFactory_);
        RENT_TOKEN = IERC20(rentToken_);
        RENT_TOKEN_SA = rentTokenSA_;
    }

    function createRentAuction(uint256 _hyperPerpId, uint256 _duration, uint256 _price, uint256 _expiry) external {
        // fetch the perp contract
        IHyperPerp hyperPerp = IHyperPerp(IHyperPerpFactory(address(WALLET_FACTORY)).perps(_hyperPerpId));
        if (address(hyperPerp) == address(0)) revert ZeroAddress();

        // check the perp position
        int64 positionSzi = hyperPerp.getPositionSzi();
        if (positionSzi == 0) revert EmptyPosition();

        // transferWallet here
        WALLET_FACTORY.safeTransferFrom(msg.sender, address(this), _hyperPerpId);

        rents[++rentId] = Rent(msg.sender, address(0), _hyperPerpId, _duration, 0, _price, _expiry, 0, 0);

        emit RentAuctionCreated(msg.sender, rentId);
    }

    function removeRentAuction(uint256 _rentId) external {
        Rent memory rent = rents[_rentId];
        if (rent.creator == address(0)) revert InvalidRentId();
        if (rent.renter != address(0)) revert OngoingRent();
        if (rent.expiry > block.timestamp) revert RentNotExpiryYet();

        // transfer back the hyper perp to rent creator
        WALLET_FACTORY.safeTransferFrom(address(this), rent.creator, rent.hyperPerpId);

        delete rents[_rentId];
    }

    function acceptRentAuction(uint256 _rentId) external {
        Rent memory rent = rents[_rentId];
        address creator = rent.creator;
        if (creator == address(0)) revert InvalidRentId();
        if (rent.renter != address(0)) revert OngoingRent();
        if (rent.expiry < block.timestamp) revert RentExpired();

        // transfer price here to charge rent fee
        uint256 price = rent.price;
        RENT_TOKEN.safeTransferFrom(msg.sender, address(this), price);

        uint256 fee = price * rentFee / BASE_FEE;
        feeAccrued += fee;
        // transfer rent price - fee to the creator
        RENT_TOKEN.safeTransfer(creator, price - fee);

        // fetch the perp contract
        IHyperPerp hyperPerp = IHyperPerp(IHyperPerpFactory(address(WALLET_FACTORY)).perps(rent.hyperPerpId));

        rent.renter = msg.sender;
        rent.startTime = block.timestamp;
        rent.initialValue = hyperPerp.getAccountValue();
        rent.initialRawUsd = hyperPerp.getAccountRawUsd();

        rents[_rentId] = rent;

        emit RentAuctionAccepted(msg.sender, _rentId);
    }

    function settleRent(uint256 _rentId) external {
        Rent memory rent = rents[_rentId];
        if (rent.creator == address(0)) revert InvalidRentId();
        if (rent.startTime == 0) revert RentNotStartedYet();
        if (block.timestamp < rent.startTime + rent.duration) revert OngoingRent();

        // calculate pnl
        uint256 hyperPerpId = rent.hyperPerpId;
        IHyperPerp hyperPerp = IHyperPerp(IHyperPerpFactory(address(WALLET_FACTORY)).perps(hyperPerpId));
        if (address(hyperPerp) == address(0)) revert ZeroAddress();

        int64 endValue = hyperPerp.getAccountValue();
        int64 endRawUsd = hyperPerp.getAccountRawUsd();

        int64 pnl = (endValue - rent.initialValue) - (endRawUsd - rent.initialRawUsd);

        // transfer pnl to the renter at core if there was any earning during the renting period
        // NOTE check if it requires only a send spot to evm (unified account)
        if (pnl > 0) {
            // remove pnl from core to evm (send spot to )
            hyperPerp.sendSpot(RENT_TOKEN_SA, RENT_TOKEN_CORE_ID, uint64(pnl));
            // transfer usdc to the renter
            RENT_TOKEN.safeTransfer(rent.renter, uint64(pnl));
        }

        // transfer back the hyper perp to the rent creator
        WALLET_FACTORY.safeTransferFrom(address(this), rent.creator, hyperPerpId);

        delete rents[_rentId];
    }

    function withdrawFee(address to, uint256 amount) external onlyOwner {
        feeAccrued -= amount;
        RENT_TOKEN.safeTransfer(to, amount);
    }

    function setRentFee(uint256 _rentFee) external onlyOwner {
        if (_rentFee > BASE_FEE) revert FeeTooHigh();
        rentFee = _rentFee;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
