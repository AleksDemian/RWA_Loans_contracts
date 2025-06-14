// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {RWALending} from "../src/RWALending.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployRWALending is Script {
    function run() external {
        vm.startBroadcast();

        // MockERC20 stablecoin = new MockERC20("Stablecoin", "STB", 18);
        address stablecoin = vm.envAddress("STABLECOIN_ADDRESS");

        address token = vm.envAddress("TOKEN_ADDRESS");

        address goldPriceFeed = vm.envAddress("GOLD_PRICE_FEED");

        RWALending lending = new RWALending(stablecoin, token, goldPriceFeed, 500);

        vm.stopBroadcast();

        console2.log("Stablecoin deployed to:", address(stablecoin));
        console2.log("RWAToken deployed to:", address(token));
        console2.log("RWALending deployed to:", address(lending));
    }
}
