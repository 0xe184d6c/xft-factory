// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ByteFactory {
    event Deployed(address indexed contractAddress, bytes32 salt, bytes metadata);

    /// @notice Deploy arbitrary bytecode using CREATE2.
    /// @param initCode The complete creation code (bytecode + encoded constructor arguments).
    /// @param salt A 32-byte value for deterministic deployment.
    ///             For idempotency, you may use keccak256(initCode) if no custom salt is supplied.
    /// @param metadata Additional deployment metadata for logging.
    /// @return deployedAddress The address of the newly deployed contract.
    function deployBytecode(
        bytes memory initCode,
        bytes32 salt,
        bytes memory metadata
    ) external returns (address deployedAddress) {
        require(initCode.length > 0, "ByteFactory: initCode is empty");
        assembly {
            deployedAddress := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        require(deployedAddress != address(0), "ByteFactory: Deployment failed");
        emit Deployed(deployedAddress, salt, metadata);
    }

    /// @notice Predict the address of a contract deployed with given initCode and salt.
    /// @param initCode The complete creation code.
    /// @param salt The salt value used in deployment.
    /// @return predicted The computed contract address.
    function predictAddress(
        bytes memory initCode,
        bytes32 salt
    ) external view returns (address predicted) {
        bytes32 initCodeHash = keccak256(initCode);
        predicted = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            initCodeHash
        )))));
    }
}
