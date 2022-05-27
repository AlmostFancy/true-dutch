pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {Hevm} from "./Hevm.sol";

contract TrueTest is Test {
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
}
