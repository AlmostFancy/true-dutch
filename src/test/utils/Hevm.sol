// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

interface Hevm {
    /// @notice Sets the block timestamp.
    function warp(uint256) external;
}
