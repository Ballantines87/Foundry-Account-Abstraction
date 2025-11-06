// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPointContractAddress;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAINID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAINID = 300;
    uint256 constant LOCAL_ANVIL_CHAINID = 31337;

    // a temporary wallet address on sepolia that we'll use as DISPOSABLE burner wallet to deploy contracts and fund our MinimalAccount contract for **TESTING** purposes
    address constant BURNER_WALLET_ADDRESS = address(1); // INSERT HERE

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig activeNetworkConfig) chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[ETH_SEPOLIA_CHAINID] = getEthSepoliaConfig();

        chainIdToNetworkConfig[
            ZKSYNC_SEPOLIA_CHAINID
        ] = getZkSyncSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getEthSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaEthNetworkConfig)
    {
        return
            NetworkConfig({
                entryPointContractAddress: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
                account: BURNER_WALLET_ADDRESS
            });
    }

    function getZkSyncSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory zkSyncSepoliaNetworkConfig)
    {
        return
            NetworkConfig({
                // N.B. since zkSync has NATIVE account abstraction, there is no entry point contract address -> so for now we'll leave address(0) here
                entryPointContractAddress: address(0),
                account: BURNER_WALLET_ADDRESS
            });
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_ANVIL_CHAINID) {
            return getOrCreateAnvilEthConfig();
        } else if (chainIdToNetworkConfig[chainId].account != address(0)) {
            return chainIdToNetworkConfig[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.entryPointContractAddress != address(0)) {
            return localNetworkConfig;
        } else {
            // TO DO: deploy MOCK entryPoint contract
            vm.startBroadcast();

            vm.stopBroadcast();
        }
    }

    function run() external {}
}
