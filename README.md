[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](https://github.com/AlmostFancy/true-dutch/blob/master/LICENSE.txt)
[![NPM](https://img.shields.io/npm/v/@almost-fancy/true-dutch)](https://www.npmjs.com/package/@almost-fancy/true-dutch)

## Installation

Forge:

```sh
forge install almostfancy/true-dutch
```

Hardhat or Truffle:

```sh
npm install -D @almost-fancy/true-dutch
```

## Usage

To get started, you can use the library as follows:

```solidity
pragma solidity ^0.8.4;

import { TrueDutchAuction } from "@almost-fancy/true-dutch/src/TrueDutchAuction.sol";

contract AlmostFancy is TrueDutchAuction, ERC721A {
  constructor(address payable _beneficiary)
    ERC721A("AlmostFancy", "AF")
    TrueDutchAuction(
      DutchAuctionConfig({
        saleStartTime: dutchSaleTime,
        startPriceWei: 0.99 ether,
        endPriceWei: 0.09 ether,
        duration: 9 hours,
        dropInterval: 15 minutes,
        maxBidsPerAddress: 0,
        available: 1111,
        maxPerTx: 3
      }),
      _beneficiary
    )
  {}

  function placeBid(uint256 quantity) external payable {
    _placeAuctionBid(msg.sender, quantity);
  }

  function _handleBidPlaced(
    address whom,
    uint256 quantity,
    uint256 priceToPay
  ) internal override {
    uint256 cost = priceToPay * quantity;
    _safeMint(whom, quantity); // call ERC721A#_safeMint to actually get the asset to the caller
  }
}

```

## License

Distributed under the ISC License. See `LICENSE.txt` for more information.

## Contact Us

- Erik (lead dev) - [@erosemberg\_](https://twitter.com/erosemberg_)
