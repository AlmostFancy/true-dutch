// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { Test } from 'forge-std/Test.sol';
import { MockTrueDutch } from './mocks/MockTrueDutch.sol';
import { ITrueDutchAuction } from '../contracts/ITrueDutchAuction.sol';

contract TrueDutchAuctionTest is Test {
    MockTrueDutch auction;

    function setUp() public {
        auction = new MockTrueDutch();
    }

    function testPlaceBid() public {
        uint256 req = auction.getDutchPrice();
        address addr = address(0);
        hoax(addr); // prank address(0) and make sure we have enough eth
        auction.placeBid{ value: req }(1);
        assertEq(auction.balanceOf(addr), 1);
    }

     function testPlaceFourBids() public {
        uint256 req = auction.getDutchPrice();
        address addr = address(0);
        hoax(addr); // prank address(0) and make sure we have enough eth
        vm.expectRevert(ITrueDutchAuction.AuctionBidExceedsMaxPerTx.selector);
        auction.placeBid{ value: req * 4 }(4);
    }
}
