//SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./UniswapV2Pair.sol";
import "./UniswapV2Library.sol";

contract UniswapV2Factory {
    error UniswapV2Factory_Forbidden();
    error UniswapV2Factory_PairExists();
    address public feeTo;
    address public feeToSetter;

    event PairCreated(address indexed token0, address indexed token1, address pair);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        (address token0, address token1) = UniswapV2Library.sortTokens(tokenA, tokenB);
        address pair = UniswapV2Library.pairFor(address(this), token0, token1);
        if (UniswapV2Library.isContract(pair)) {
            revert UniswapV2Factory_PairExists();
        } else {
            UniswapV2Pair(pair).initialize(token0, token1);
            emit PairCreated(token0, token1, pair);
        }
        return pair;
    }

    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert UniswapV2Factory_Forbidden();
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert UniswapV2Factory_Forbidden();
        feeToSetter = _feeToSetter;
    }
}
