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
        token.delegate(i_billionaire);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new BoxGovernor(token, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(governor));
        timeLock.revokeRole(adminRole, i_billionaire);

        vm.stopPrank();

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

        assertEq(uint256(governor.state(proposalId)), 0);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        assertEq(uint256(governor.state(proposalId)), 1);

        // 2. Vote
        string memory reason = "just learning and testing";
        uint8 voteWay = 1; // voting yes

        vm.prank(i_billionaire); // this set who is casting the vote
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the tx
        bytes32 descHash = keccak256(abi.encodePacked(desc));
        governor.queue(targets, values, calldatas, descHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. execute
        governor.execute(targets, values, calldatas, descHash);

        // assert
        assertEq(box.getNumber(), valueToStore);
    }
}
