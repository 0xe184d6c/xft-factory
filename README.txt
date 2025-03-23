XFT FACTORY



1 Script compiles SimpleStorage to bytecode.
2 Script encodes constructor param (42).
3 Script asks factory to predict address with salt and bytecode+params.
4 Factory returns predicted address.
5 Script calls factory to deploy with salt, bytecode, and params.
6 Factory uses CREATE2 to deploy on blockchain.
7 Blockchain deploys contract at predicted address.
8 Factory returns transaction hash to script.
9 Script connects to deployed contract.
10 Contract returns initial value (42).
11 Script updates value to 100.
12 Contract confirms new value (100).












Version: 1.2
Deploying XFTFactory...
$ npx hardhat run scripts/deploy.ts --network sepolia
Deploying XFTFactory...
XFTFactory deployed to: 0x130cAB7C4D3e7fc2eF41B2b8169e01b3a920E14E
Deploying XFTFactory...
XFTFactory deployed to: 0x130cAB7C4D3e7fc2eF41B2b8169e01b3a920E14E
Deployment transaction hash: 0xc3d11cb2e0de4a171ae60454a931fbb84dd42730370181aee72c958a0ed160f7
XFTFactory deployed to: 0x130cAB7C4D3e7fc2eF41B2b8169e01b3a920E14E
Deployment transaction hash: 0xc3d11cb2e0de4a171ae60454a931fbb84dd42730370181aee72c958a0ed160f7
Waiting for confirmations...
Verifying contract on Etherscan...
Deployment transaction hash: 0xc3d11cb2e0de4a171ae60454a931fbb84dd42730370181aee72c958a0ed160f7
Waiting for confirmations...
Verifying contract on Etherscan...
Waiting for confirmations...
Verifying contract on Etherscan...
Successfully submitted source code for contract
Verifying contract on Etherscan...
Successfully submitted source code for contract
Successfully submitted source code for contract
contracts/XFTFactory.sol:XFTFactory at 0x130cAB7C4D3e7fc2eF41B2b8169e01b3a920E14E
for verification on the block explorer. Waiting for verification result...

Successfully verified contract XFTFactory on the block explorer.
https://sepolia.etherscan.io/address/0x130cAB7C4D3e7fc2eF41B2b8169e01b3a920E14E#code











XFTFactory Contract: Software Flow and How It Works
Let me walk you through the XFTFactory contract's design, components, and operational flow.
Core Purpose
The XFTFactory is a smart contract deployment factory using CREATE2 for deterministic address generation. It provides:

Preset management for reusable contract templates
Enhanced metadata tracking for deployments
Simplified deployment workflows with role-based access
Detailed event logging for off-chain tracking

Main Components
1. Access Control System
solidityCopybytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
// Inherits from AccessControl for role management

DEFAULT_ADMIN_ROLE: Can register and update presets, manage deployers
DEPLOYER_ROLE: Can deploy contracts using the factory

2. Preset Management
solidityCopymapping(bytes32 => bytes) public presets;
mapping(bytes32 => string) public presetNames;

Presets are reusable bytecode templates stored on-chain
Each preset has a unique ID and descriptive name
Reduces gas costs and prevents deployment errors by reusing verified code

3. Deployment Tracking
solidityCopystruct DeploymentInfo {
    address deployer;
    uint256 timestamp;
    bytes32 presetId;
    bytes32 bytecodeHash;
    string metadata;
}
mapping(address => DeploymentInfo) public deploymentInfo;

Comprehensive deployment history for each contract
Metadata field for additional deployment context

4. Salt Generation
solidityCopymapping(address => uint256) public userSaltNonce;
function _generateSalt(bytes32 presetId, bytes memory constructorArgs) internal returns (uint256)

Automatic salt generation to prevent collisions
Includes chain ID, deployer address, and incrementing nonce

Operational Flow
1. Preset Registration Flow
CopyAdmin -> registerPreset() -> Store bytecode -> Emit PresetRegistered

Admin prepares contract bytecode off-chain
Admin calls registerPreset() with name and bytecode
Factory stores the bytecode and assigns a preset ID
Event is emitted for off-chain tracking

2. Basic Deployment Flow
CopyDeployer -> deployPreset() -> _generateSalt() -> _deploy() -> _deployWithTracking() -> Emit Deployed

Deployer selects preset and provides constructor arguments
Factory generates a unique salt
Factory deploys contract using CREATE2 with the bytecode and salt
Deployment details are recorded and event emitted

3. Proxy Deployment Flow
CopyDeployer -> deployProxy() -> _deploy() -> Initialize Proxy -> Emit ProxyDeployed

Deployer provides implementation address and initialization data
Factory generates proxy bytecode with implementation address
Factory deploys proxy using CREATE2
Factory initializes proxy (if initialization data provided)
Deployment details are recorded and event emitted

4. Batch Deployment Flow
CopyDeployer -> batchDeployPresets() -> [For each config] -> _deployWithTracking() -> Emit BatchDeployed

Deployer provides array of deployment configurations
For each configuration:

Factory generates unique salt
Factory deploys contract with appropriate preset and constructor args
Deployment details are recorded


Array of deployed addresses is returned
Batch event emitted with all addresses

Key Technical Features
CREATE2 Deployment
The core deployment mechanism uses CREATE2 opcode:
solidityCopyassembly {
    deployed := create2(0, add(bytecode, 32), mload(bytecode), salt)
}
This ensures:

Deterministic addresses regardless of deployer's nonce
Ability to predict contract addresses before deployment
Gas efficiency for bytecode deployment

Salt Management
solidityCopyfunction _generateSalt(bytes32 presetId, bytes memory constructorArgs) internal returns (uint256) {
    return uint256(keccak256(abi.encode(
        block.chainid,
        msg.sender,
        userSaltNonce[msg.sender]++,
        presetId,
        keccak256(constructorArgs)
    )));
}
Each salt includes:

Chain ID (for cross-chain safety)
Deployer address
Incrementing nonce (to allow repeated deployments)
Preset ID and constructor args (for context-awareness)

Address Prediction
solidityCopyfunction predictPresetAddress(bytes32 presetId, bytes calldata constructorArgs) external view
This calculates the exact address where a contract will be deployed:

Computes the salt that would be used
Applies the CREATE2 address formula
Returns predicted address without deploying

Use Cases and Examples
1. Standard Token Deployment
solidityCopy// Admin registers ERC20 preset
bytes32 erc20PresetId = factory.registerPreset("ERC20", erc20Bytecode);

// Deployer deploys a new token
address tokenAddress = factory.deployPreset(
    erc20PresetId,
    abi.encode("MyToken", "MTK", 18),
    "Project: MyDApp v1.0"
);
2. Upgradeable Contract System
solidityCopy// Deploy implementation
address implementation = factory.deployPreset(implementationPresetId, "");

// Deploy multiple proxies pointing to it
address proxy = factory.deployProxy(
    implementation,
    abi.encodeWithSignature("initialize(string,string)", "Name", "Symbol"),
    "Proxy for MyToken v1"
);
3. Coordinated Multi-Contract Deployment
solidityCopy// Configure batch deployment for an entire system
DeploymentConfig[] memory configs = new DeploymentConfig[](3);
configs[0] = DeploymentConfig(tokenPresetId, abi.encode("Token", "TKN"), "Token v1");
configs[1] = DeploymentConfig(vaultPresetId, abi.encode(params), "Vault v1");
configs[2] = DeploymentConfig(stakingPresetId, abi.encode(params), "Staking v1");

// Deploy entire system in one transaction
address[] memory addresses = factory.batchDeployPresets(configs);
Event System
The event system provides a comprehensive audit trail:
solidityCopyevent Deployed(address indexed deployedAddress, uint256 indexed salt, bytes32 bytecodeHash, string metadata);
event PresetRegistered(bytes32 indexed presetId, string name);
event ProxyDeployed(address indexed proxy, address indexed implementation, string metadata);
event BatchDeployed(address[] deployedAddresses, uint256 saltBase);
This enables:

Off-chain indexing of all deployments
Full audit history of contract origins
Metadata association for deployment context

Benefits

Simplified Deployment: Reusable templates and automated salt generation
Enhanced Security: Role-based access and CREATE2 determinism
Complete Tracking: Comprehensive on-chain and event-based history
Gas Efficiency: Reduced bytecode transmission through preset reuse
Seamless Coordination: Predictable addresses and batch deployment







