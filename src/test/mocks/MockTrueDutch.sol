pragma solidity ^0.8.4;

import {TrueDutchAuction} from "../../TrueDutchAuction.sol";
import {console2} from "forge-std/console2.sol";

contract MockTrueDutch is TrueDutchAuction {
    constructor()
        TrueDutchAuction(
            DutchAuctionConfig({
                saleStartTime: block.timestamp + 1 minutes,
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
        uint256 priceToPay
    ) internal view override {
        console2.log(
            "Handled bid placed (addr, q, p)",
            whom,
            quantity,
            priceToPay
        );
    }
}
