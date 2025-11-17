// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test{

    Raffle public raffle;
    HelperConfig public helperConfig;

    event RaffleEntered(address indexed player);

    uint256 entranceFee;
    uint256 interval; 
    address vrfCoordinator; 
    bytes32 gasLane; 
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);

    }

    function testRaffleInitializeInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }


    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        address playerRecorded = raffle.getPlayer(0);

        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public{
        vm.prank(PLAYER);

        vm.expectEmit(true,false,false,false,  address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

    }

    function testDontAllowPlayersToEnterWhileRaffleCalculating()public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");  // <-- Invalid consumer error

        // Act /Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
    }

    function testCheckUpKeepReturnsFlaseIfItHasNoBalance()public{
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1 );

        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        assert(!upkeepNeeded);

    }

    function testCheckUpKeepReturnsFalseIfNotOpen() public{
         // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

     
}