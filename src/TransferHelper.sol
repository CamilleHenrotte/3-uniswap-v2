// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

library TransferHelper {
    // Sort tokens by address to ensure consistent ordering
    error TransferHelper_TransferFailed();
    function safeTransfer(address token, address to, uint256 amount) public {
        (bool success, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        if (!success) revert TransferHelper_TransferFailed();
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
    function safeTransferFrom(address token, address from, address to, uint256 amount) public {
        (bool success, ) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        if (!success) revert TransferHelper_TransferFailed();
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
}
