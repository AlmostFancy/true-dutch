// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { Test } from 'forge-std/Test.sol';
import { MockTrueDutch } from './mocks/MockTrueDutch.sol';
import { ITrueDutchAuction } from '../ITrueDutchAuction.sol';
import { console2 } from 'forge-std/console2.sol';

contract TrueDutchAuctionTest is Test {
    MockTrueDutch auction;

    function setUp() public {
        auction = new MockTrueDutch();
    }

    function testAuctionNotStarted() public {
        hoax(address(1));
        vm.expectRevert(ITrueDutchAuction.AuctionNotStarted.selector);
        auction.placeBid(2);
    }

    function testPlaceBid() public {
        vm.warp(block.timestamp + 2 minutes);
        uint256 req = auction.getDutchPrice();
        address addr = address(0);
        hoax(addr); // prank address(0) and make sure we have enough eth
        auction.placeBid{ value: req }(1);
        assertEq(auction.balanceOf(addr), 1);
    }
}
