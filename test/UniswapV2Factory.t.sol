//SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {DeployUniswapV2Factory} from "../script/DeployUniswapV2Factory.sol";
import {DeployToken0, DeployToken1} from "../script/DeployERC20.sol";
import {ERC20Token} from "../src/ERC20Token.sol";
import {Test} from "forge-std/Test.sol";

contract UniswapV2PairTest is Test {
    UniswapV2Factory factory;
    ERC20Token token0;
    ERC20Token token1;
    address ADMIN = makeAddr("admin");
    address PROTOCOL_OWNER = makeAddr("protocol_owner");

    function setUp() public {
        factory = new DeployUniswapV2Factory().run();
        token0 = new DeployToken0().run();
        token1 = new DeployToken1().run();
    }

    function testCreatePair() public {
        UniswapV2Pair pair = UniswapV2Pair(factory.createPair(address(token0), address(token1)));
        assert(pair.token0() == address(token0));
        assert(pair.token1() == address(token1));
    }
    function testSetFeeTo() public {
        vm.prank(PROTOCOL_OWNER);
        factory.setFeeTo(ADMIN);
        assert(factory.feeTo() == ADMIN);
    }
    function testSetFeeToUnauthorized() public {
        vm.expectRevert(UniswapV2Factory.UniswapV2Factory_Forbidden.selector);
        vm.prank(ADMIN);
        factory.setFeeTo(ADMIN);
    }

    function testSetFeeToSetter() public {
        vm.prank(PROTOCOL_OWNER);
        factory.setFeeToSetter(ADMIN);
        assert(factory.feeToSetter() == ADMIN);
    }
    function testSetFeeToSetterUnauthorized() public {
        vm.expectRevert(UniswapV2Factory.UniswapV2Factory_Forbidden.selector);
        vm.prank(ADMIN);
        factory.setFeeToSetter(ADMIN);
    }
}
