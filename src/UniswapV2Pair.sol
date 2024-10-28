//SPDX-License-Identifier: MIT
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

pragma solidity =0.8.28;

contract UniswapV2Pair is ReentrancyGuard {
    error UniswapV2Pair_Forbidden();
    error UniswapV2Pair_Overflow();
    struct Uq112x112 {
        uint112 integer;
        uint112 decimal;
    }
    uint224 constant Q112 = 2 ** 112;
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public immutable factory;
    address public token0;
    address public token1;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    Uq112x112 public price0CumulativeLast;
    Uq112x112 public price1CumulativeLast;
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

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        if (msg.sender != factory) revert UniswapV2Pair_Forbidden();
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - (reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - (reserve1));
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        require(success, "Transfer failed");

        assembly {
            // Check if return data exists
            let size := returndatasize()

            // If there’s return data, verify the first 32 bytes as a boolean
            if gt(size, 0) {
                let result := mload(0x40) // Load free memory pointer
                returndatacopy(result, 0, 32) // Copy only 32 bytes of return data
                if iszero(mload(result)) {
                    revert(0, 0)
                } // Revert if transfer returned false
            }
        }
    }
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert UniswapV2Pair_Overflow();
        Uq112x112 memory timeElapsed = Uq112x112({
            integer: uint112(uint32((block.timestamp) - blockTimestampLast)),
            decimal: 0
        });
        blockTimestampLast = uint32(block.timestamp);
        if (timeElapsed.integer > 0 && _reserve0 != 0 && _reserve1 != 0) {
            Uq112x112 memory uq_reserv0 = Uq112x112({integer: _reserve0, decimal: 0});
            Uq112x112 memory uq_reserv1 = Uq112x112({integer: _reserve1, decimal: 0});
            price0CumulativeLast = _uqadd(price0CumulativeLast, _uqmul(timeElapsed, _uqdiv(uq_reserv0, uq_reserv1)));
            price1CumulativeLast = _uqadd(price1CumulativeLast, _uqmul(timeElapsed, _uqdiv(uq_reserv1, uq_reserv0)));
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }
    function _uqdiv(Uq112x112 memory x, Uq112x112 memory y) internal pure returns (Uq112x112 memory) {
        uint256 result = ((x.integer * Q112 + x.decimal) * Q112) / (y.integer * Q112 + y.decimal);
        return Uq112x112({integer: uint112(result / Q112), decimal: uint112(result % Q112)});
    }
    function _uqmul(Uq112x112 memory x, Uq112x112 memory y) internal pure returns (Uq112x112 memory) {
        uint256 result = ((x.integer * Q112 + x.decimal) * (y.integer * Q112 + y.decimal)) / (Q112);
        return Uq112x112({integer: uint112(result / Q112), decimal: uint112(result % Q112)});
    }
    function _uqadd(Uq112x112 memory x, Uq112x112 memory y) internal pure returns (Uq112x112 memory) {
        uint256 xValue = uint256(x.integer) * Q112 + x.decimal;
        uint256 yValue = uint256(y.integer) * Q112 + y.decimal;
        uint256 result;
        unchecked {
            result = (xValue + yValue);
        }
        return Uq112x112({integer: uint112(result / Q112), decimal: uint112(result % Q112)});
    }
}
