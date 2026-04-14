// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DemoGame} from "src/DemoGame.sol";

contract DeployScript is Script {
    function run() public {
        // Get deployment parameters from environment variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address slpHubAddress = vm.envAddress("SLP_HUB_ADDRESS");
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");

        // Validate addresses
        require(slpHubAddress != address(0), "SLP_HUB_ADDRESS cannot be zero address");
        require(adminAddress != address(0), "ADMIN_ADDRESS cannot be zero address");

        // Get deployer address for logging
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("=== DemoGame Deployment ===");
        console.log("Deployer Address:", deployerAddress);
        console.log("SLP Hub Address:", slpHubAddress);
        console.log("Admin Address:", adminAddress);
        console.log("====================================");

        vm.startBroadcast(deployerPrivateKey);
        DemoGame demoGame = new DemoGame(slpHubAddress, adminAddress);
        vm.stopBroadcast();

        console.log("DemoGame deployed to:", address(demoGame));
    }
}
