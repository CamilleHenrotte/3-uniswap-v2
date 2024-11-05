//SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {DeployUniswapV2Pair} from "../script/DeployUniswapV2Pair.sol";
import {DeployFlashBorrower} from "../script/DeployFlashBorrower.sol";
import {IERC3156FlashBorrower} from "lib/openzeppelin-contracts/contracts/interfaces/IERC3156FlashBorrower.sol";
import {FlashBorrower} from "../src/FlashBorrower.sol";
import {ERC20Token} from "../src/ERC20Token.sol";
import {Test, console} from "forge-std/Test.sol";

contract UniswapV2PairTest is Test {
    UniswapV2Pair pair;
    address USER = makeAddr("user");
    address TOKEN_BANK = makeAddr("token_bank");
    ERC20Token token0;
    ERC20Token token1;
    FlashBorrower flashBorrower;
    uint256 constant AMOUNT_TO_SWAP = 1 * 10 ** 18;
    uint256 constant AMOUNT_TO_BURN = 5 * 10 ** 18;
    uint256 constant INITIAL_LIQUIDITY_TOKEN_0 = 10 * 10 ** 18;
    uint256 constant INITIAL_LIQUIDITY_TOKEN_1 = 20 * 10 ** 18;
    uint256 constant INITIAL_USER_BALANCE_TOKEN_0 = 100 * 10 ** 18;
    uint256 constant INITIAL_USER_BALANCE_TOKEN_1 = 100 * 10 ** 18;

    function setUp() public {
        flashBorrower = new DeployFlashBorrower().run();
        pair = new DeployUniswapV2Pair().run();
        token0 = ERC20Token(pair.token0());
        token1 = ERC20Token(pair.token1());
        vm.prank(TOKEN_BANK);
        token0.transfer(USER, INITIAL_USER_BALANCE_TOKEN_0);
        vm.prank(TOKEN_BANK);
        token1.transfer(USER, INITIAL_USER_BALANCE_TOKEN_1);
    }
    modifier addInitialLiquidity() {
        vm.prank(TOKEN_BANK);
        token0.approve(address(pair), INITIAL_LIQUIDITY_TOKEN_0);
        vm.prank(TOKEN_BANK);
        token1.approve(address(pair), INITIAL_LIQUIDITY_TOKEN_1);
        vm.prank(TOKEN_BANK);
        pair.addLiquidity(INITIAL_LIQUIDITY_TOKEN_0, INITIAL_LIQUIDITY_TOKEN_1, 0, 0, USER, block.timestamp + 5);
        _;
    }
    modifier userAddLiquidity() {
        vm.prank(USER);
        token0.approve(address(pair), AMOUNT_TO_SWAP);
        vm.prank(USER);
        token1.approve(address(pair), AMOUNT_TO_SWAP * 2);
        vm.prank(USER);
        pair.addLiquidity(AMOUNT_TO_SWAP, AMOUNT_TO_SWAP * 2, 0, 0, USER, block.timestamp + 5);
        _;
    }
    function testMinimumLiquidity() public {
        uint256 minLiquidity = pair.MINIMUM_LIQUIDITY();
        assertEq(minLiquidity, 10 ** 3);
    }
    function testCallBackSuccess() public {
        assertEq(pair.CALLBACK_SUCCESS(), keccak256("ERC3156FlashBorrower.onFlashLoan"));
    }
    function testFeeBasisPoints() public {
        assertEq(pair.FEE_BASIS_POINTS(), 3);
    }
    function testInitializeCalledOnlyByFactory() public {
        vm.expectRevert(UniswapV2Pair.UniswapV2Pair_Forbidden.selector);
        vm.prank(makeAddr("nonFactoryAddress"));
        pair.initialize(address(0), address(0));
    }
    function testSwapExactTokensForTokensRevertsIfSlippage() public addInitialLiquidity {
        vm.prank(USER);
        token0.approve(address(pair), AMOUNT_TO_SWAP);
        uint balance = token0.balanceOf(USER);
        uint256 allowance = token0.allowance(USER, address(pair));
        vm.expectRevert(UniswapV2Pair.UniswapV2Pair_InsufficientOutputAmount.selector);
        vm.prank(USER);
        pair.swapExactTokensForTokens(AMOUNT_TO_SWAP, INITIAL_LIQUIDITY_TOKEN_1, true, USER, block.timestamp + 5);
    }
    function testSwapExactTokensForTokens() public addInitialLiquidity {
        vm.prank(USER);
        token0.approve(address(pair), AMOUNT_TO_SWAP);
        vm.prank(USER);
        pair.swapExactTokensForTokens(AMOUNT_TO_SWAP, 0, true, USER, block.timestamp + 5);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 balance0 = token0.balanceOf(USER);
        uint256 balance1 = token1.balanceOf(USER);
        assertEq(balance0, INITIAL_USER_BALANCE_TOKEN_0 - AMOUNT_TO_SWAP);
        assertGt(balance1, INITIAL_USER_BALANCE_TOKEN_1);
    }
    function testAddLiquidityRevertsIfSlippage() public addInitialLiquidity {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        console.log(reserve0, reserve1);
        uint quote = pair.quote(reserve0, reserve1, AMOUNT_TO_SWAP);
        console.log(quote);
        vm.prank(USER);
        token0.approve(address(pair), AMOUNT_TO_SWAP);
        vm.prank(USER);
        token1.approve(address(pair), AMOUNT_TO_SWAP);
        vm.prank(USER);
        vm.expectRevert(UniswapV2Pair.UniswapV2Pair_InsufficientToken1Amount.selector);
        pair.addLiquidity(AMOUNT_TO_SWAP, 10 * AMOUNT_TO_SWAP, 0, AMOUNT_TO_SWAP * 10, USER, block.timestamp + 5);
    }
    function testAddLiquidity() public addInitialLiquidity userAddLiquidity {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 balance0 = token0.balanceOf(USER);
        uint256 balance1 = token1.balanceOf(USER);
        uint256 balancePair = pair.balanceOf(USER);
        assertEq(balance0, INITIAL_USER_BALANCE_TOKEN_0 - AMOUNT_TO_SWAP);
        assertEq(balance1, INITIAL_USER_BALANCE_TOKEN_1 - AMOUNT_TO_SWAP * 2);
        assertGt(balancePair, 0);
        assertEq(reserve0, INITIAL_LIQUIDITY_TOKEN_0 + AMOUNT_TO_SWAP);
        assertEq(reserve1, INITIAL_LIQUIDITY_TOKEN_1 + AMOUNT_TO_SWAP * 2);
    }

    function testRemoveLiquidityRevertsIfSlippage() public addInitialLiquidity userAddLiquidity {
        pair.approve(address(pair), AMOUNT_TO_BURN);
        vm.prank(USER);
        vm.expectRevert(UniswapV2Pair.UniswapV2Pair_InsufficientLiquidity.selector);
        pair.removeLiquidity(AMOUNT_TO_BURN, 2 * AMOUNT_TO_BURN, 0, USER, block.timestamp + 5);
    }
    function testRemoveLiquidity() public addInitialLiquidity userAddLiquidity {
        uint256 balance0Before = token0.balanceOf(USER);
        uint256 balance1Before = token1.balanceOf(USER);
        (uint256 reserve0Before, uint256 reserve1Before, ) = pair.getReserves();
        uint256 balancePairBefore = pair.balanceOf(USER);
        vm.prank(USER);
        pair.removeLiquidity(AMOUNT_TO_BURN, 0, 0, USER, block.timestamp + 5);
        uint256 balance0After = token0.balanceOf(USER);
        uint256 balance1After = token1.balanceOf(USER);
        (uint256 reserve0After, uint256 reserve1After, ) = pair.getReserves();
        uint256 balancePairAfter = pair.balanceOf(USER);
        assertEq(balancePairAfter, balancePairBefore - AMOUNT_TO_BURN);
        assertGt(balance0After, balance0Before);
        assertGt(balance1After, balance1Before);
        assertGt(reserve0Before, reserve0After);
        assertGt(reserve1Before, reserve1After);
    }
    function testFlashLoan() public addInitialLiquidity {
        uint256 fee = pair.flashFee(address(token0), AMOUNT_TO_SWAP);
        vm.prank(TOKEN_BANK);
        token0.transfer(address(flashBorrower), fee);
        uint256 balance0Before = token0.balanceOf(USER);
        uint256 balanceFlashBefore = token0.balanceOf(address(flashBorrower));
        vm.prank(USER);
        pair.flashLoan(IERC3156FlashBorrower(address(flashBorrower)), address(token0), AMOUNT_TO_SWAP, bytes(""));
        uint256 balance0After = token0.balanceOf(USER);
        uint256 balanceFlashAfter = token0.balanceOf(address(flashBorrower));
        assertEq(balance0After, balance0Before);
        assertEq(balanceFlashAfter, balanceFlashBefore - fee);
    }
    function testMaxFlashLoan() public addInitialLiquidity {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(pair.maxFlashLoan(address(token0)), reserve0);
        assertEq(pair.maxFlashLoan(address(token1)), reserve1);
    }
}
