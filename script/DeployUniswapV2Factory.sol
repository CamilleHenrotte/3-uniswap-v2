// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import {Script} from "forge-std/Script.sol";
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";

contract DeployUniswapV2Factory is Script {
    address PROTOCOL_OWNER = makeAddr("protocol_owner");
    function run() external returns (UniswapV2Factory) {
        vm.startBroadcast();
        UniswapV2Factory factory = new UniswapV2Factory(PROTOCOL_OWNER);
        vm.stopBroadcast();
        return factory;
    }
}
