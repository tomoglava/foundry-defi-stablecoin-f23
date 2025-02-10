// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {Script} from "lib/forge-std/src/Script.sol";


contract DeployDSC is Script {
    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        //DSCEngine engine = new DSCEngine();

        vm.stopBroadcast();
    }
}