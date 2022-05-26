// SPDX-License-Identifier: MIT
// TrueDutchAuction contracts, written by AlmostFancy
pragma solidity ^0.8.4;

import "./ITrueDutchAuction.sol";
import "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";

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

    constructor(DutchAuctionConfig memory _config, address payable _beneficiary)
    {
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
        // solhint-disable-next-line reason-string
        require(
            // solhint-disable-next-line not-rely-on-time
            saleConfig.saleStartTime != 0 &&
                block.timestamp >= saleConfig.saleStartTime,
            "TrueDutchAuction: Dutch auction has not started yet!"
        );
        // solhint-disable-next-line reason-string
        require(
            quantity <= saleConfig.maxPerTx,
            "TrueDutchAuction: Exceeds max per tx"
        );
        uint256 dutchPrice = getDutchPrice();
        // solhint-disable-next-line reason-string
        require(
            msg.value >= quantity * dutchPrice,
            "TrueDutchAuction: Not enough ETH sent"
        );
        if (saleConfig.maxBidsPerAddress != 0) {
            // solhint-disable-next-line reason-string
            require(
                auctionBids[who].length + quantity <=
                    saleConfig.maxBidsPerAddress,
                "TrueDutchAuction: That amount will exceed the max allowed bids per address"
            );
        }
        // solhint-disable-next-line reason-string
        require(
            totalSales + quantity <= saleConfig.available,
            "TrueDutchAuction: Dutch Auction has already sold out!"
        );

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
        // solhint-disable-next-line reason-string
        require(refundsEnabled, "TrueDutchAuction: Refunds are not enabled!");
        // solhint-disable-next-line reason-string
        require(
            !claimedRefunds[msg.sender],
            "TrueDutchAuction: You have already claimed your refund!"
        );
        AuctionBid[] memory bids = auctionBids[msg.sender];
        // solhint-disable-next-line reason-string
        require(
            bids.length > 0,
            "TrueDutchAuction: You are not eligible for a refund!"
        );

        uint256 refund = 0;
        for (uint256 i = 0; i < bids.length; i++) {
            AuctionBid memory bid = bids[i];
            refund += (bid.bid * bid.quantity) - lastDutchPrice; // should be safe from underflows
        }
        claimedRefunds[msg.sender] = true;
        // solhint-disable-next-line reason-string
        require(
            refund > 0,
            "TrueDutchAuction: You are not eligible for a refund!"
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = msg.sender.call{value: refund}("");
        require(success, "TrueDutchAuction: Refund failed.");
        emit RefundPaid(msg.sender, bids, lastDutchPrice, refund);
    }

    // @dev withdraws profits made from the dutch auction, multiplies
    // the total amount of sales against the set dutch auction price
    // can only be called once.
    function _withdrawDutchProfits() internal nonReentrant {
        // solhint-disable-next-line reason-string
        require(
            !auctionProfitsWithdrawn,
            "TrueDutchAuction: Dutch Auction profits have already been paid out"
        );
        // solhint-disable-next-line reason-string
        require(
            lastDutchPrice > 0,
            "TrueDutchAuction: The Dutch Auction has not ended yet"
        );
        uint256 profits = totalSales * lastDutchPrice;

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = beneficiary.call{value: profits}("");
        // solhint-disable-next-line reason-string
        require(success, "TrueDutchAuction: Withdraw failed.");
        auctionProfitsWithdrawn = true;
    }

    // @dev this is meant to be used as a last resort or for dev purposes
    // this contract's authors are not made responsible for misuse of this
    // method
    function _forceDutchFloor(uint256 floor) internal {
        lastDutchPrice = floor;
    }

    function getBidsFrom(address bidder)
        external
        view
        override
        returns (AuctionBid[] memory)
    {
        return auctionBids[bidder];
    }
}
