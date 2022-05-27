pragma solidity ^0.8.4;

import {TrueTest} from "./utils/TrueTest.sol";
import {MockTrueDutch} from "./mocks/MockTrueDutch.sol";
import {ITrueDutchAuction} from "../ITrueDutchAuction.sol";
import {console2} from "forge-std/console2.sol";

contract TrueDutchAuctionTest is TrueTest {
    MockTrueDutch auction;

    function setUp() public {
        auction = new MockTrueDutch();
    }

    function testAuctionStarted() public {
        hoax(address(1));
        vm.expectRevert(ITrueDutchAuction.AuctionNotStarted.selector);
        auction.placeBid(2);
    }

    function testBidWarped() public {
        hevm.warp(block.timestamp + 2 minutes);
        hoax(address(1));
        uint256 req = auction.getDutchPrice();
        auction.placeBid{value: req}(1);
    }
}
