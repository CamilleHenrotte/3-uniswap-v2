//SPDX-License-Identifier: MIT
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC3156FlashBorrower} from "lib/openzeppelin-contracts/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import "./TransferHelper.sol";
import "./FixedPointLibrary.sol";
import "./IUniswapV2Factory.sol";
import "./MathLibrary.sol";

pragma solidity =0.8.28;

contract UniswapV2Pair is ReentrancyGuard, ERC20 {
    using TransferHelper for address;
    using FixedPointLibrary for FixedPointLibrary.FixedPoint;

    error UniswapV2Pair_Forbidden();
    error UniswapV2Pair_Overflow();
    error UniswapV2Pair_Expired();
    error UniswapV2Pair_InsufficientInputAmount();
    error UniswapV2Pair_InsufficientOutputAmount();
    error UniswapV2Pair_InsufficientToken1Amount();
    error UniswapV2Pair_InsufficientToken0Amount();
    error UniswapV2Pair_EcxessiveInputAmount();
    error UniswapV2Pair_InsufficientLiquidity();
    error UniswapV2Pair_K();
    error UniswapV2Pair_InvalidToken();
    error UniswapV2Pair_TransferFailed();
    error UniswapV2Pair_CallbackFailed();
    error UniswapV2Pair_TransferBackFailed();

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant FEE_BASIS_POINTS = 3;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    address public immutable factory;
    address public token0;
    address public token1;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    FixedPointLibrary.FixedPoint public price0CumulativeLast;
    FixedPointLibrary.FixedPoint public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool inputIsToken0, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    modifier ensure(uint256 deadline) {
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
        uint256 amountIn,
        uint256 amountOutMin,
        bool inputIsToken0,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (uint256 amountOut) {
        (uint112 reserveIn, uint112 reserveOut, address tokenIn) = inputIsToken0
            ? (reserve0, reserve1, token0)
            : (reserve1, reserve0, token1);
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < amountOutMin) revert UniswapV2Pair_InsufficientOutputAmount();
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountOut, inputIsToken0, to);
    }
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        bool inputIsToken0,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (uint256 amountIn) {
        (uint112 reserveIn, uint112 reserveOut, address tokenIn) = inputIsToken0
            ? (reserve0, reserve1, token0)
            : (reserve1, reserve0, token1);
        amountIn = getAmountIn(amountOut, reserveIn, reserveOut);
        if (amountIn > amountInMax) revert UniswapV2Pair_EcxessiveInputAmount();
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountOut, inputIsToken0, to);
    }
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = quote(amount0Desired, reserve0, reserve1);
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert UniswapV2Pair_InsufficientToken1Amount();
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = quote(amount1Desired, reserve0, reserve1);
                if (amount0Optimal > amount0Desired) revert UniswapV2Pair_InsufficientLiquidity();
                if (amount0Optimal < amount0Min) revert UniswapV2Pair_InsufficientToken0Amount();
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);
        liquidity = _mint(to);
    }
    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external nonReentrant ensure(deadline) returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _burnLiquidity(to, liquidity);
        if (amount0 < amount0Min || amount1 < amount1Min) revert UniswapV2Pair_InsufficientLiquidity();
    }
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        (uint112 reserve0, uint112 reserve1, ) = getReserves();
        uint256 fee = flashFee(token, amount);
        bool transferSuccess = IERC20(token).transfer(address(receiver), amount);
        if (!transferSuccess) revert UniswapV2Pair_TransferFailed();
        bytes32 callbackSuccess = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        if (callbackSuccess != CALLBACK_SUCCESS) revert UniswapV2Pair_CallbackFailed();
        bool transferBackSuccess = IERC20(token).transferFrom(address(receiver), address(this), amount + fee);
        if (!transferBackSuccess) revert UniswapV2Pair_TransferBackFailed();
        uint256 balance0 = IERC20(token).balanceOf(address(this));
        uint256 balance1 = IERC20(token).balanceOf(address(this));
        _update(balance0, balance1, reserve0, reserve1);
        return true;
    }
    function maxFlashLoan(address token) external nonReentrant returns (uint256) {
        if (token == token0) return (reserve0);
        else if (token == token1) return (reserve1);
        else {
            revert UniswapV2Pair_InvalidToken();
        }
    }
    function skim(address to) external nonReentrant {
        address _token0 = token0;
        address _token1 = token1;
        _token0.safeTransfer(to, IERC20(_token0).balanceOf(address(this)) - (reserve0));
        _token1.safeTransfer(to, IERC20(_token1).balanceOf(address(this)) - (reserve1));
    }
    function sync() external {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function name() public view virtual override returns (string memory) {
        return "Uniswap V2 Liquidity Token";
    }
    function symbol() public view virtual override returns (string memory) {
        return "UNI-V2";
    }
    function flashFee(address token, uint256 amount) public view returns (uint256) {
        if (token != token0 && token != token1) revert UniswapV2Pair_InvalidToken();
        return (amount * 3) / 1000;
    }
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        if (amountIn <= 0) revert UniswapV2Pair_InsufficientInputAmount();
        if (reserveIn <= 0 || reserveOut <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        if (amountOut <= 0) revert UniswapV2Pair_InsufficientOutputAmount();
        if (reserveIn <= 0 || reserveOut <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        if (amountA <= 0) revert UniswapV2Pair_InsufficientInputAmount();
        if (reserveA <= 0 || reserveB <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        amountB = (amountA * reserveB) / reserveA;
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert UniswapV2Pair_Overflow();
        FixedPointLibrary.FixedPoint memory timeElapsed = FixedPointLibrary.FixedPoint({
            integer: uint112(uint32((block.timestamp - blockTimestampLast))),
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
    function _swap(uint256 amountOut, bool inputIsToken0, address to) internal {
        (uint112 reserveIn, uint112 reserveOut, address tokenOut) = inputIsToken0
            ? (reserve0, reserve1, token1)
            : (reserve1, reserve0, token0);
        tokenOut.safeTransfer(to, amountOut);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        (uint256 balanceIn, uint256 balanceOut) = inputIsToken0 ? (balance0, balance1) : (balance1, balance0);
        if (balanceIn < reserveIn) revert UniswapV2Pair_InsufficientInputAmount();
        uint256 amountIn = balanceIn - reserveIn;
        {
            uint256 leftSide = (((1000 * balanceIn - FEE_BASIS_POINTS * amountIn) / 1_000_000_000) * balanceOut);
            uint256 rightSide = (((1000 * reserveIn) / 1_000_000_000) * reserveOut);
            if (leftSide < rightSide) revert UniswapV2Pair_K();
        }
        _update(balance0, balance1, reserve0, reserve1);
        emit Swap(msg.sender, amountIn, amountOut, inputIsToken0, to);
    }

    function _mint(address to) internal returns (uint256 liquidity) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = MathLibrary.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = MathLibrary.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        if (liquidity <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        bool feeOn = _mintFee(_reserve0, _reserve1);
        _update(balance0, balance1, _reserve0, _reserve1);
        _mint(to, liquidity);
        if (feeOn) kLast = reserve0 * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = MathLibrary.sqrt(_reserve0 * _reserve1);
                uint256 rootKLast = MathLibrary.sqrt(_kLast);
                uint256 liquidity = (totalSupply() * (rootKLast - rootK)) / (5 * rootKLast + rootK);
                transfer(feeTo, liquidity);
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
    function _burnLiquidity(address to, uint256 liquidity) internal returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1;
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        amount0 = (liquidity * _reserve0) / _totalSupply;
        amount1 = (liquidity * _reserve1) / _totalSupply;
        if (balanceOf(msg.sender) <= liquidity) revert UniswapV2Pair_InsufficientLiquidity();
        if (amount0 <= 0 || amount1 <= 0) revert UniswapV2Pair_InsufficientLiquidity();
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);
        _burn(msg.sender, liquidity);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = reserve0 * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }
}
