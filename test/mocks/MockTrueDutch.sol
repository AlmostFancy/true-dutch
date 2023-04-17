// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { TrueDutchAuction } from '../../contracts/TrueDutchAuction.sol';

// @dev Represents a mocked dutch auction which simulates emitting tokens by
// updating a balance mapping.
contract MockTrueDutch is TrueDutchAuction {
    mapping(address => uint256) private balances;

    constructor()
        TrueDutchAuction(
            DutchAuctionConfig({
                saleStartTime: block.timestamp,
                startPriceWei: 1 ether,
                endPriceWei: 0.1 ether,
                duration: 1 hours,
                dropInterval: 15 minutes,
                maxBidsPerAddress: 0,
                available: 10,
                maxPerTx: 3
            }),
            payable(address(this))
        )
    {}

    function placeBid(uint256 quantity) external payable {
        _placeAuctionBid(msg.sender, quantity);
    }

    function _handleBidPlaced(
        address whom,
        uint256 quantity,
        uint256 _priceToPay
    ) internal override {
        balances[whom] += quantity;
    }

    function balanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }
}
