// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Script.sol";
import "../src/FlashBorrower.sol";

contract DeployFlashBorrower is Script {
    function run() external returns (FlashBorrower) {
        vm.startBroadcast();
        FlashBorrower flashBorrower = new FlashBorrower();
        vm.stopBroadcast();
        return flashBorrower;
    }
}
