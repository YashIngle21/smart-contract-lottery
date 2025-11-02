// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {


    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 numPlayers, uint256 raffleState);
    
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* Events */
   
    event RaffleWinnerPicked(address indexed winner);

    /* State variables */
    
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The dyuration of lottery in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinatorV2, bytes32 gasLane, uint256 subscriptionId ,uint32 callbackGasLimit)
     VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    event RaffleEnter(address indexed player);

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough value sent");
        // require(s_raffleState == RaffleState.OPEN, "Raffle is not open");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(s_raffleState  != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        
        s_players.push(payable(msg.sender));
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender); 
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restrat the lottery 
     */
    function checkUpKeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimestamp) >= i_interval) ;
        bool isOopen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOopen && hasBalance && hasPlayers;
        return (upkeepNeeded, "0x0");
    }
    
    // 1. get a random number
    // 2. Use a random number to pick a winner and pay them
    // 3. Be automated so that we don't have to manually pick a winner
    function performUpkeep(bytes calldata /* performData */) external {
        // Check interval
        (bool upKeepNeeded,) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }


        s_raffleState = RaffleState.CALCULATING;

        // Request random number from Chainlink VRF
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, 
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

    }


    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        // TODO: Implement the logic for fulfilling the random words

        uint256 indexOfWInner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWInner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        (bool success, ) = winner.call{value:address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }
        emit RaffleWinnerPicked(winner);
    }
    /**
    * Getter functions
     */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

     
}