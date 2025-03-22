// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title XFTFactory
 * @dev Factory contract for deterministic deployment of smart contracts using CREATE2
 * with access control, gas optimizations, and batch deployment functionality
 */
contract XFTFactory {
    // ======== EVENTS ========
    event Deployed(address indexed deployedAddress, uint256 indexed salt, bytes32 bytecodeHash);
    event DeployedWithParams(address indexed deployedAddress, uint256 indexed salt, bytes32 bytecodeHash, bytes params);
    event BatchDeployed(address[] deployedAddresses, uint256 indexed saltBase);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // ======== STATE VARIABLES ========
    address public owner;
    mapping(bytes32 => bool) public saltBytecodeUsed; // Tracks salt+bytecode combinations
    mapping(address => bool) public isDeployed;
    
    // ======== MODIFIERS ========
    modifier onlyOwner() {
        require(msg.sender == owner, "XFTFactory: caller is not the owner");
        _;
    }

    // ======== CONSTRUCTOR ========
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    // ======== OWNER FUNCTIONS ========
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "XFTFactory: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // ======== DEPLOYMENT FUNCTIONS ========
    /**
     * @dev Deploy a contract using CREATE2
     * @param salt Unique salt for address derivation
     * @param bytecode The bytecode of the contract to deploy
     * @return deployedAddress The address of the deployed contract
     */
    function deploy(uint256 salt, bytes calldata bytecode) external onlyOwner returns (address deployedAddress) {
        require(bytecode.length > 0, "XFTFactory: invalid bytecode");
        
        // Check for salt+bytecode reuse
        bytes32 saltBytecodeHash = keccak256(abi.encodePacked(salt, keccak256(bytecode)));
        require(!saltBytecodeUsed[saltBytecodeHash], "XFTFactory: salt already used for this bytecode");
        
        // Mark as used
        saltBytecodeUsed[saltBytecodeHash] = true;
        
        // Deploy using CREATE2
        assembly {
            // Properly handle calldata bytes
            let ptr := mload(0x40) // Get free memory pointer
            
            // Copy bytecode from calldata to memory
            calldatacopy(
                ptr,                             // Destination in memory
                add(bytecode.offset, 32),        // Skip 4 bytes function selector + 32 bytes salt + 32 bytes offset
                bytecode.length                  // Length of bytecode
            )
            
            // Update free memory pointer
            mstore(0x40, add(ptr, add(bytecode.length, 32)))
            
            deployedAddress := create2(
                0,                // No ETH sent with deployment
                ptr,              // Pointer to bytecode in memory
                bytecode.length,  // Size of bytecode
                salt              // Salt for address derivation
            )
            
            // Check deployment success
            if iszero(deployedAddress) {
                // Revert with error message
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error selector
                mstore(4, 32)     // String offset
                mstore(36, 21)    // String length
                mstore(68, "Deployment failed")
                revert(0, 100)
            }
        }
        
        // Update tracking
        isDeployed[deployedAddress] = true;
        
        // Emit deployment event
        emit Deployed(deployedAddress, salt, keccak256(bytecode));
        
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
    ) external onlyOwner returns (address deployedAddress) {
        require(bytecode.length > 0, "XFTFactory: invalid bytecode");
        
        // Check for salt+bytecode reuse
        bytes32 saltBytecodeHash = keccak256(abi.encodePacked(salt, keccak256(abi.encodePacked(bytecode, constructorArgs))));
        require(!saltBytecodeUsed[saltBytecodeHash], "XFTFactory: salt already used for this bytecode+args");
        
        // Mark as used
        saltBytecodeUsed[saltBytecodeHash] = true;
        
        // Prepare complete bytecode with constructor arguments
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);
        
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
            if iszero(deployedAddress) {
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error selector
                mstore(4, 32)     // String offset
                mstore(36, 21)    // String length
                mstore(68, "Deployment failed")
                revert(0, 100)
            }
        }
        
        // Update tracking
        isDeployed[deployedAddress] = true;
        
        // Emit deployment event with constructor args
        emit DeployedWithParams(deployedAddress, salt, keccak256(fullBytecode), constructorArgs);
        
        return deployedAddress;
    }
    
    /**
     * @dev Deploy multiple contracts in a single transaction
     * @param saltBase Base salt value for all deployments
     * @param bytecodes Array of bytecodes to deploy
     * @return deployedAddresses Array of deployed contract addresses
     */
    function batchDeploy(
        uint256 saltBase,
        bytes[] calldata bytecodes
    ) external onlyOwner returns (address[] memory deployedAddresses) {
        require(bytecodes.length > 0, "XFTFactory: empty bytecodes array");
        
        deployedAddresses = new address[](bytecodes.length);
        
        for (uint256 i = 0; i < bytecodes.length; i++) {
            require(bytecodes[i].length > 0, "XFTFactory: invalid bytecode");
            
            // Generate unique salt for each deployment
            uint256 salt = uint256(keccak256(abi.encodePacked(saltBase, i)));
            
            // Check for salt+bytecode reuse
            bytes32 saltBytecodeHash = keccak256(abi.encodePacked(salt, keccak256(bytecodes[i])));
            require(!saltBytecodeUsed[saltBytecodeHash], "XFTFactory: salt already used for this bytecode");
            
            // Mark as used
            saltBytecodeUsed[saltBytecodeHash] = true;
            
            address deployedAddress;
            bytes calldata bytecode = bytecodes[i];
            
            // Deploy using CREATE2
            assembly {
                // Get memory pointer
                let ptr := mload(0x40)
                
                // Get position in calldata for this bytecode array item
                let bytecodeOffset := add(bytecodes.offset, mul(i, 0x20))
                bytecodeOffset := add(bytecodeOffset, calldataload(bytecodeOffset))
                
                // Copy bytecode from calldata to memory
                let bytecodeLength := calldataload(bytecodeOffset)
                calldatacopy(
                    ptr,                         // Destination in memory
                    add(bytecodeOffset, 0x20),   // Source in calldata (skip length)
                    bytecodeLength               // Size
                )
                
                // Update free memory pointer
                mstore(0x40, add(ptr, add(bytecodeLength, 32)))
                
                deployedAddress := create2(
                    0,                // No ETH sent
                    ptr,              // Pointer to bytecode
                    bytecodeLength,   // Length of bytecode
                    salt              // Salt value
                )
                
                // Check deployment success
                if iszero(deployedAddress) {
                    mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error selector
                    mstore(4, 32)     // String offset
                    mstore(36, 32)    // String length
                    mstore(68, "Batch deployment failed at index")
                    mstore(100, i)
                    revert(0, 132)
                }
            }
            
            // Update tracking
            isDeployed[deployedAddress] = true;
            
            // Store the deployed address
            deployedAddresses[i] = deployedAddress;
            
            // Emit individual deployment event
            emit Deployed(deployedAddress, salt, keccak256(bytecodes[i]));
        }
        
        // Emit batch deployment event
        emit BatchDeployed(deployedAddresses, saltBase);
        
        return deployedAddresses;
    }
    
    /**
     * @dev Deploy proxy contracts pointing to an implementation
     * @param saltBase Base salt value for all deployments
     * @param count Number of proxies to deploy
     * @param implementation Address of the implementation contract
     * @return deployedAddresses Array of deployed proxy addresses
     */
    function deployProxies(
        uint256 saltBase,
        uint256 count,
        address implementation
    ) external onlyOwner returns (address[] memory deployedAddresses) {
        require(implementation != address(0), "XFTFactory: invalid implementation");
        require(count > 0, "XFTFactory: count must be greater than zero");
        
        // Minimal proxy bytecode (EIP-1167)
        bytes memory proxyCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        deployedAddresses = new address[](count);
        
        for (uint256 i = 0; i < count; i++) {
            // Generate unique salt for each deployment
            uint256 salt = uint256(keccak256(abi.encodePacked(saltBase, i)));
            
            // Check for salt+bytecode reuse
            bytes32 saltBytecodeHash = keccak256(abi.encodePacked(salt, keccak256(proxyCode)));
            require(!saltBytecodeUsed[saltBytecodeHash], "XFTFactory: salt already used for this proxy");
            
            // Mark as used
            saltBytecodeUsed[saltBytecodeHash] = true;
            
            address deployedAddress;
            
            // Deploy proxy using CREATE2
            assembly {
                let ptr := mload(0x40) // Get free memory pointer
                
                // Copy the proxy bytecode to memory (it's already in memory, just need the pointer)
                let bytecodeLength := mload(proxyCode)
                let bytecodePtr := add(proxyCode, 32)
                
                deployedAddress := create2(
                    0,                // No ETH sent
                    bytecodePtr,      // Pointer to bytecode
                    bytecodeLength,   // Length of bytecode
                    salt              // Salt value
                )
                
                // Check deployment success
                if iszero(deployedAddress) {
                    mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error selector
                    mstore(4, 32)     // String offset
                    mstore(36, 27)    // String length
                    mstore(68, "Proxy deployment failed")
                    revert(0, 100)
                }
            }
            
            // Update tracking
            isDeployed[deployedAddress] = true;
            
            // Store the deployed address
            deployedAddresses[i] = deployedAddress;
            
            // Emit individual deployment event
            emit Deployed(deployedAddress, salt, keccak256(proxyCode));
        }
        
        // Emit batch deployment event
        emit BatchDeployed(deployedAddresses, saltBase);
        
        return deployedAddresses;
    }
    
    // ======== VIEW FUNCTIONS ========
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
     * @dev Predicts multiple addresses for batch deployment
     * @param saltBase Base salt value for all deployments
     * @param bytecodes Array of bytecodes to deploy
     * @return Array of addresses where contracts would be deployed
     */
    function predictBatchAddresses(
        uint256 saltBase, 
        bytes[] calldata bytecodes
    ) external view returns (address[] memory) {
        address[] memory addresses = new address[](bytecodes.length);
        
        for (uint256 i = 0; i < bytecodes.length; i++) {
            uint256 salt = uint256(keccak256(abi.encodePacked(saltBase, i)));
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecodes[i])
            )))));
        }
        
        return addresses;
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
     * @dev Checks if a salt+bytecode combination has been used
     * @param salt The salt value
     * @param bytecode The contract bytecode
     * @return True if this combination has been used
     */
    function isSaltUsed(uint256 salt, bytes calldata bytecode) external view returns (bool) {
        bytes32 saltBytecodeHash = keccak256(abi.encodePacked(salt, keccak256(bytecode)));
        return saltBytecodeUsed[saltBytecodeHash];
    }
}