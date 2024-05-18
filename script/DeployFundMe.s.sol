// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFundMe is Script {
    // we need our main function to be called run()
    function run() external returns (FundMe, HelperConfig) {
        // before startBroadcast -> not a "real" tx
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        address priceFeed = helperConfig.activeNetworkConfig();

        // after startBroadcast -> "real" tx
        // vm is one of the cheat codes
        vm.startBroadcast(); // this means, everything after this line, we actually send to the rpc

        FundMe fundMe = new FundMe(priceFeed);

        vm.stopBroadcast();
        return (fundMe, helperConfig);
    }
}
