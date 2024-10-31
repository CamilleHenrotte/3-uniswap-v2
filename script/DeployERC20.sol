// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Script.sol";
import "../src/ERC20Token.sol";
contract DeployToken0 is Script {
    address TOKEN_BANK = makeAddr("token_bank");
    uint256 constant TOKEN_INITIAL_SUPPLY = 1_000_000 * 10 ** 18;
    function run() external returns (ERC20Token) {
        vm.startBroadcast();
        ERC20Token token0 = new ERC20Token("Token 0", "TK0", TOKEN_INITIAL_SUPPLY);
        bool success = token0.transfer(TOKEN_BANK, TOKEN_INITIAL_SUPPLY);
        require(success, "Token 0 transfer failed");
        vm.stopBroadcast();
        return token0;
    }
}
contract DeployToken1 is Script {
    address TOKEN_BANK = makeAddr("token_bank");
    uint256 constant TOKEN_INITIAL_SUPPLY = 1_000_000 * 10 ** 18;
    function run() external returns (ERC20Token) {
        vm.startBroadcast();
        ERC20Token token1 = new ERC20Token("Token 1", "TK1", TOKEN_INITIAL_SUPPLY);
        bool success = token1.transfer(TOKEN_BANK, TOKEN_INITIAL_SUPPLY);
        require(success, "Token 1 transfer failed");
        vm.stopBroadcast();
        return token1;
    }
}
