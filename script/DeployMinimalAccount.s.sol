// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract DeployMinimalAccount is Script {
    MinimalAccount minimalAccount;

    function run() external returns (HelperConfig, address) {
        return deployMinimalAccount();
    }

    function deployMinimalAccount()
        public
        returns (HelperConfig config, address minimalAccountAddress)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        vm.startBroadcast(networkConfig.account);
        minimalAccount = new MinimalAccount(
            IEntryPoint(networkConfig.entryPointContractAddress)
        );
        minimalAccount.transferOwnership(msg.sender);
        vm.stopBroadcast();

        return (helperConfig, address(minimalAccount));
    }
}
