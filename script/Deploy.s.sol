// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is Script {
    function run() public returns (RWAToken) {
        vm.startBroadcast();

        RWAToken token = new RWAToken();

        vm.stopBroadcast();

        console.log("RWAToken deployed to:", address(token));

        return token;
    }
}
