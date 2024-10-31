// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import {Script} from "forge-std/Script.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";
import {DeployToken0, DeployToken1} from "../script/DeployERC20.sol";
import {DeployUniswapV2Factory} from "../script/DeployUniswapV2Factory.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract DeployUniswapV2Pair is Script {
    function run() external returns (UniswapV2Pair) {
        ERC20Token token0 = new DeployToken0().run();
        ERC20Token token1 = new DeployToken1().run();
        UniswapV2Factory factory = new DeployUniswapV2Factory().run();
        vm.startBroadcast();
        UniswapV2Pair pair = UniswapV2Pair(factory.createPair(address(token0), address(token1)));
        vm.stopBroadcast();
        return pair;
    }
}
