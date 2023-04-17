// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ITrueDutchAuction} from "./ITrueDutchAuction.sol";
import {ReentrancyGuard} from "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";

abstract contract TrueDutchAuction is ITrueDutchAuction, ReentrancyGuard {
    struct DutchAuctionConfig {
        uint256 saleStartTime;
        uint256 startPriceWei;
        uint256 endPriceWei;
        uint256 duration;
        uint256 dropInterval;
        uint256 maxBidsPerAddress; // @dev if this is set to 0, there is no limit
        uint256 available; // @dev total amount of tokens that can be sold during dutch
        uint256 maxPerTx; // @dev max amount of bids per transaction
    }

    constructor(
        DutchAuctionConfig memory _config,
        address payable _beneficiary
    ) {
        dutchConfig = _config;
        dropsPerStep =
            (_config.startPriceWei - _config.endPriceWei) /
            (_config.duration / _config.dropInterval);
        beneficiary = _beneficiary;
    }

    address payable public beneficiary;

    uint256 private totalSales; // @dev track amount of sales during dutch auction
    DutchAuctionConfig public dutchConfig;
    uint256 private dropsPerStep;

    uint256 internal lastDutchPrice;

    bool public refundsEnabled;
    mapping(address => bool) private claimedRefunds;
    mapping(address => AuctionBid[]) public auctionBids;
    bool private auctionProfitsWithdrawn;

    function _setBeneficiary(address payable _beneficiary) internal {
        beneficiary = _beneficiary;
    }

    function _setDutchConfig(DutchAuctionConfig memory _config) internal {
        dutchConfig = _config;
        dropsPerStep =
            (_config.startPriceWei - _config.endPriceWei) /
            (_config.duration / _config.dropInterval);
    }

    // @dev this method is called by _placeAuctionBid() after the sanity checks have
    // been completed.
    // this is where safeMint() and similar functions should be called
    function _handleBidPlaced(
        address whom,
        uint256 quantity,
        uint256 priceToPay
    ) internal virtual;

    function _placeAuctionBid(address who, uint256 quantity) internal virtual {
        DutchAuctionConfig memory saleConfig = dutchConfig;
        if (
            block.timestamp < saleConfig.saleStartTime ||
            saleConfig.saleStartTime == 0
        ) {
            revert AuctionNotStarted();
        }
        if (quantity > saleConfig.maxPerTx) {
            revert AuctionBidExceedsMaxPerTx();
        }
        uint256 dutchPrice = getDutchPrice();
        if (msg.value < quantity * dutchPrice) {
            revert AuctionBidBelowRequiredValue();
        }
        if (saleConfig.maxBidsPerAddress != 0) {
            if (
                auctionBids[who].length + quantity >
                saleConfig.maxBidsPerAddress
            ) {
                revert AuctionBidExceedsMax();
            }
        }
        if (totalSales + quantity > saleConfig.available) {
            revert AuctionSoldOut();
        }

        if (totalSales + quantity == saleConfig.available) {
            lastDutchPrice = dutchPrice;
        }

        totalSales += quantity;
        _handleBidPlaced(who, quantity, dutchPrice); // @dev check _handleBidPlaced() notes
        // store auction data for refunds later on
        auctionBids[who].push(
            AuctionBid({quantity: quantity, bid: dutchPrice})
        );
        emit BidPlaced(who, quantity, dutchPrice);
    }

    // @dev returns the current dutch price by calculating the steps
    function getDutchPrice() public view override returns (uint256) {
        DutchAuctionConfig memory saleConfig = dutchConfig;
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp < saleConfig.saleStartTime) {
            return saleConfig.startPriceWei;
        }

        if (
            // solhint-disable-next-line not-rely-on-time
            block.timestamp - saleConfig.saleStartTime >= saleConfig.duration
        ) {
            return saleConfig.endPriceWei;
        } else {
            // solhint-disable-next-line not-rely-on-time
            uint256 steps = (block.timestamp - saleConfig.saleStartTime) /
                saleConfig.dropInterval;
            return saleConfig.startPriceWei - (steps * dropsPerStep);
        }
    }

    function _toggleRefunds(bool state) internal {
        refundsEnabled = state;
    }

    function claimRefund() external nonReentrant {
        if (!refundsEnabled) {
            revert RefundsNotEnabled();
        }
        if (claimedRefunds[msg.sender]) {
            revert RefundAlreadyClaimed();
        }
        AuctionBid[] memory bids = auctionBids[msg.sender];
        if (bids.length == 0) {
            revert NotEligibleForRefund();
        }
        uint256 bidLength = bids.length;
        uint256 refund = 0;
        for (uint256 i = 0; i < bidLength; i = _uncheckedIncrement(i)) {
            AuctionBid memory bid = bids[i];
            refund += (bid.bid * bid.quantity) - lastDutchPrice; // should be safe
        }
        claimedRefunds[msg.sender] = true;
        if (refund == 0) {
            revert NotEligibleForRefund();
        }
        emit RefundPaid(msg.sender, bids, lastDutchPrice, refund);
        (bool success, ) = msg.sender.call{value: refund}("");
        if (!success) {
            revert RefundFailed();
        }
    }

    // @dev withdraws profits made from the dutch auction, multiplies
    // the total amount of sales against the set dutch auction price
    // can only be called once.
    function _withdrawDutchProfits() internal nonReentrant {
        if (auctionProfitsWithdrawn) {
            revert AuctionProfitsAlreadyWidthdrawn();
        }
        if (lastDutchPrice == 0) {
            revert AuctionNotOver();
        }
        uint256 profits = totalSales * lastDutchPrice;
        auctionProfitsWithdrawn = true;
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = beneficiary.call{value: profits}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    // @dev this is meant to be used as a last resort or for dev purposes
    // this contract's authors are not made responsible for misuse of this
    // method
    function _forceDutchFloor(uint256 floor) internal {
        lastDutchPrice = floor;
    }

    function getBidsFrom(
        address bidder
    ) external view override returns (AuctionBid[] memory) {
        return auctionBids[bidder];
    }

    function _uncheckedIncrement(
        uint256 counter
    ) private pure returns (uint256) {
        unchecked {
            return counter + 1;
        }
    }
}
