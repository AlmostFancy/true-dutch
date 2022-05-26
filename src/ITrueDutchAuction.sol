// SPDX-License-Identifier: MIT
// TrueDutchAuction contracts, written by AlmostFancy
pragma solidity ^0.8.4;

interface ITrueDutchAuction {
    struct AuctionBid {
        uint256 quantity;
        uint256 bid;
    }

    event RefundPaid(
        address indexed to,
        AuctionBid[] bids,
        uint256 dutch,
        uint256 refund
    );

    event BidPlaced(
        address indexed from,
        uint256 quantity,
        uint256 currentPrice
    );

    function getBidsFrom(address bidder)
        external
        view
        returns (AuctionBid[] memory);

    function getDutchPrice() external view returns (uint256);
}
