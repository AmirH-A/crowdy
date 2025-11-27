// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {CrowdfundCampaign} from "../src/CrowdfundCampaign.sol";

contract CrowdfundCampaignScript is Script {
    CrowdfundCampaign public campaign;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        campaign = new CrowdfundCampaign();

        vm.stopBroadcast();
    }
}
