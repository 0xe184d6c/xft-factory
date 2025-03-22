// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title XFTFactory
 * @dev Factory contract for deterministic deployment of smart contracts using CREATE2
 */
contract XFTFactory {
    // Events
    event Deployed(address indexed deployedAddress, uint256 indexed salt, bytes32 bytecodeHash);
    event DeployedWithParams(address indexed deployedAddress, uint256 indexed salt, bytes32 bytecodeHash, bytes params);
    
    // Mappings to track deployments
    mapping(address => bool) public isDeployed;
    mapping(bytes32 => address) public getDeployedAddress;
    
    /**
     * @dev Deploy a contract using CREATE2
     * @param salt Unique salt for address derivation
     * @param bytecode The bytecode of the contract to deploy
     * @return deployedAddress The address of the deployed contract
     */
    function deploy(uint256 salt, bytes calldata bytecode) external returns (address deployedAddress) {
        // Compute bytecode hash for logging and tracking
        bytes32 bytecodeHash = keccak256(bytecode);
        
        // Deploy using CREATE2
        assembly {
            // Properly handle calldata bytes
            let ptr := mload(0x40) // Get free memory pointer
            calldatacopy(ptr, bytecode.offset, bytecode.length) // Copy bytecode from calldata to memory
            
            deployedAddress := create2(
                0,                // No ETH sent with deployment
                ptr,              // Pointer to bytecode in memory
                bytecode.length,  // Size of bytecode
                salt              // Salt for address derivation
            )
            
            // Check deployment success
            if iszero(extcodesize(deployedAddress)) {
                revert(0, 0)
            }
        }
        
        // Update tracking mappings
        isDeployed[deployedAddress] = true;
        getDeployedAddress[bytecodeHash] = deployedAddress;
        
        // Emit deployment event
        emit Deployed(deployedAddress, salt, bytecodeHash);
        
        return deployedAddress;
    }
    
    /**
     * @dev Deploy a contract with constructor parameters
     * @param salt Unique salt for address derivation
     * @param bytecode The bytecode of the contract to deploy
     * @param constructorArgs The encoded constructor arguments
     * @return deployedAddress The address of the deployed contract
     */
    function deployWithParams(
        uint256 salt,
        bytes calldata bytecode,
        bytes calldata constructorArgs
    ) external returns (address deployedAddress) {
        // Prepare complete bytecode with constructor arguments
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);
        bytes32 bytecodeHash = keccak256(fullBytecode);
        
        // Deploy using CREATE2
        assembly {
            let ptr := add(fullBytecode, 32)  // Skip length field (32 bytes)
            
            deployedAddress := create2(
                0,                            // No ETH sent
                ptr,                          // Pointer to bytecode
                mload(fullBytecode),          // Length of bytecode
                salt                          // Salt value
            )
            
            // Check deployment success
            if iszero(extcodesize(deployedAddress)) {
                revert(0, 0)
            }
        }
        
        // Update tracking mappings
        isDeployed[deployedAddress] = true;
        getDeployedAddress[bytecodeHash] = deployedAddress;
        
        // Emit deployment event with constructor args
        emit DeployedWithParams(deployedAddress, salt, bytecodeHash, constructorArgs);
        
        return deployedAddress;
    }
    
    /**
     * @dev Predicts the address where a contract will be deployed
     * @param salt Unique salt for address derivation
     * @param bytecode The bytecode of the contract (with or without constructor args)
     * @return The calculated future address of the contract
     */
    function predictAddress(uint256 salt, bytes calldata bytecode) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(bytecode)
        )))));
    }
    
    /**
     * @dev Verifies if an address was deployed through this factory
     * @param deployedAddress The address to check
     * @return True if the address was deployed by this factory
     */
    function verifyDeployment(address deployedAddress) external view returns (bool) {
        return isDeployed[deployedAddress];
    }
    
    /**
     * @dev Generates a unique salt based on sender and custom input
     * @param customSalt User-provided salt component
     * @return A unique salt derived from msg.sender and custom input
     */
    function generateSalt(uint256 customSalt) external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(msg.sender, customSalt, block.timestamp)));
    }
}