//SPDX-License-Identifier: MIT
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./TransferHelper.sol";
import "./FixedPointLibrary.sol";

pragma solidity =0.8.28;

contract UniswapV2Pair is ReentrancyGuard {
    using TransferHelper for address;
    using FixedPointLibrary for FixedPointLibrary.FixedPoint;

    error UniswapV2Pair_Forbidden();
    error UniswapV2Pair_Overflow();
    error UniswapV2Pair_Expired();
    error UniswapV2Pair_InsufficientInputAmount();
    error UniswapV2Pair_InsufficientOutputAmount();
    error UniswapV2Pair_EcxessiveInputAmount();
    error UniswapV2Pair_InsufficientLiquidity();

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public immutable factory;
    address public token0;
    address public token1;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    FixedPointLibrary.FixedPoint public price0CumulativeLast;
    FixedPointLibrary.FixedPoint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    modifier ensure(uint deadline) {
        if (deadline < block.timestamp) revert UniswapV2Pair_Expired();
        _;
    }
    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        if (msg.sender != factory) revert UniswapV2Pair_Forbidden();
        token0 = _token0;
        token1 = _token1;
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        bool inputIsToken0,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        (uint112 reserveIn, uint112 reserveOut, address tokenIn) = inputIsToken0
            ? (reserve0, reserve1, token0)
            : (reserve1, reserve0, token1);
        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < amountOutMin) revert UniswapV2Pair_InsufficientOutputAmount();
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountIn, amountOut, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        bool inputIsToken0,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        (uint112 reserveIn, uint112 reserveOut, address tokenIn) = inputIsToken0
            ? (reserve0, reserve1, token0)
            : (reserve1, reserve0, token1);
        uint amountIn = getAmountIn(amountOut, reserveIn, reserveOut);
        if (amountIn > amountInMax) revert UniswapV2Pair_EcxessiveInputAmount();
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountIn, amountOut, to);
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        if (amountIn <= 0) revert UniswapV2Pair_InsufficientInputAmount();
        if (reserveIn <= 0 || reserveOut <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        if (amountOut <= 0) revert UniswapV2Pair_InsufficientOutputAmount();
        if (reserveIn <= 0 || reserveOut <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _token0.safeTransfer(to, IERC20(_token0).balanceOf(address(this)) - (reserve0));
        _token1.safeTransfer(to, IERC20(_token1).balanceOf(address(this)) - (reserve1));
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert UniswapV2Pair_Overflow();
        FixedPointLibrary.FixedPoint memory timeElapsed = FixedPointLibrary.FixedPoint({
            integer: uint112(uint32((block.timestamp) - blockTimestampLast)),
            decimal: 0
        });
        blockTimestampLast = uint32(block.timestamp);
        if (timeElapsed.integer > 0 && _reserve0 != 0 && _reserve1 != 0) {
            FixedPointLibrary.FixedPoint memory uq_reserv0 = FixedPointLibrary.FixedPoint({
                integer: _reserve0,
                decimal: 0
            });
            FixedPointLibrary.FixedPoint memory uq_reserv1 = FixedPointLibrary.FixedPoint({
                integer: _reserve1,
                decimal: 0
            });
            price0CumulativeLast = price0CumulativeLast.add(timeElapsed.mul(uq_reserv0.div(uq_reserv1)));
            price0CumulativeLast = price1CumulativeLast.add(timeElapsed.mul(uq_reserv1.div(uq_reserv0)));
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }
    function _swap(uint amount0Out, uint amount1Out, address to) internal nonReentrant {}
}
