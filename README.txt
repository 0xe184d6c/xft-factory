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
