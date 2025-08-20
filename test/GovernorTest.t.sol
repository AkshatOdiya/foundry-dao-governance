// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BoxGovernor} from "src/Governor.sol";
import {Box} from "src/Box.sol";
import {GovToken} from "src/GovToken.sol";
import {TimeLock} from "src/TimeLock.sol";

contract GovernorTest is Test {
    BoxGovernor governor;
    Box box;
    GovToken token;
    TimeLock timeLock;

    address public immutable i_billionaire = makeAddr("billionaire");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    uint256 public VOTING_DELAY = 1;
    uint256[] values;

    address[] proposers;
    address[] executors;
    address[] targets;
    bytes[] calldatas;

    function setUp() public {
        token = new GovToken();
        token.mint(i_billionaire, INITIAL_SUPPLY);

        vm.startPrank(i_billionaire);
        token.delegate(i_billionaire); //  just because our user has minted tokens, doesn't mean they have voting power. It's necessary to call the delegate function to assign this weight to the user who minted.
        timeLock = new TimeLock(MIN_DELAY, proposers, executors); // Leaving the proposers and executors arrays empty is how you tell the timelock that anyone can fill these roles
        governor = new BoxGovernor(token, timeLock);

        /**
         * @notice Roles
         * Now's the point where we want to tighten up who is able to control what aspects of the DAO protocol.
         * The Timelock contract we're using contains a number of roles which we can set on deployment.
         * For example, we only want our governor to be able to submit proposals to the timelock, so this is something we want want to configure explicitly after deployment.
         * Similarly the admin role is defaulted to the address which deployed our timelock, we absolutely want this to be our governor to avoid centralization.
         */
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(governor));
        timeLock.revokeRole(adminRole, i_billionaire);

        vm.stopPrank();

        /**
         * @notice Owner of the Protocol
         * we need to assure that the timelock is set as the owner of this protocol. If you recall, the store function of our Box contract is access controlled.
         * This is meant to be called by only our DAO. But, because our DAO (the governor contract) must always check with the timelock before executing anything,
         * the timelock is what must be set as the address able to call functions on our protocol.
         */
        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1); // only timeLock can do this so this test will pass
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 666;
        string memory desc = "storing 1 in box";
        bytes memory functionCallData = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(functionCallData);
        targets.push(address(box));

        // 1. propose to DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        assertEq(uint256(governor.state(proposalId)), 0); // proposal is pending, this is because the Timelock Controller is enforcing a delay before voting on a proposal.

        // We'll need to simulate the passage of time using the vm.warp and vm.roll cheatcodes Foundry offers before we can see our state change. We'll also need to declare a VOTING_DELAY constant and assign this to 1. This will represent 1 block delay before voting is authorized.
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        assertEq(uint256(governor.state(proposalId)), 1); // proposal is active

        // 2. Vote
        string memory reason = "just learning and testing";
        uint8 voteWay = 1; // voting yes

        vm.prank(i_billionaire); // this set who is casting the vote
        governor.castVoteWithReason(proposalId, voteWay, reason);

        // Votes are cast, we'll need to advance time again. Our voting period has been defaulted to 1 week (50400 blocks)
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the tx
        /**
         * Once the VOTING_PERIOD has elapsed, a successful proposal needs to be queued before it executes. The queue function, we remember, requires all the same parameters of the original proposal (with the description having already been hashed).
         * This function uses the parameters to derive the proposalId and verify that the proposal state reflects a successful proposal. Let's go ahead and queue our proposal now!
         *
         * After a proposal is queued, we'll of course need to advance time again to account for our Timelock's configured MIN_DELAY. This is the opportunity for stakeholders to exit their position if they don't agree with the DAOs decision!
         */
        bytes32 descHash = keccak256(abi.encodePacked(desc));
        governor.queue(targets, values, calldatas, descHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. execute
        // after queuing time passes, we can finally execute
        governor.execute(targets, values, calldatas, descHash);

        // assert
        assertEq(box.getNumber(), valueToStore);
    }
}
