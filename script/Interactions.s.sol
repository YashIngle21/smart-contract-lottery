// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script,console} from "lib/forge-std/src/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig,CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";


contract CreateSubscription is Script{
    function createSubscriptionUsingConfig() public returns(uint256,address){
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator);
        return(subId,vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns(uint256,address) {
        console.log("Creating subscription on chainID :", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your sub id is: ", subId);
        console.log("Please upadte sub id in your HelperConfig.s.sol");

        return(subId,vrfCoordinator);
    }

    function run() public{
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script,CodeConstants{

    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public{
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator,subId,linkToken);
    }

    function fundSubscription(address vrfCoordinator,uint256 subId,address linkToken) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(linkToken).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(linkToken).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() public{
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{

    function addConsumerUsingConfig(address mostRecentlyDeployed) public{
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        addConsumer(mostRecentlyDeployed,vrfCoordinator,subId);
    }

    function addConsumer(address contractToAddVrf, address vrfCoordinator, uint256 subId) public {
        console.log("Adding consumer contract: ", contractToAddVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddVrf);
        vm.stopBroadcast();
    }

    function run()  external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);

    }
}