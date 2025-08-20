// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from
    "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @notice Governor.sol
 *
 * Governor.sol: This is the core of the governance system. The governor tracks proposals via the _proposals mapping
 * Proposals exist as fairly simple structs in Governor.sol
 *
 * Each proposal's state is tracked through the state function. This references the aforementioned proposal mapping and displays various properties including if it was executed,
 * if quorum was reached etc. This is the function that many front ends will call to display proposal details.
 *
 * One of the most important functions in Governor.sol is going to be propose, this is the function DAO members will call to submit a proposal for voting, the parameters passed here are very specific.
 *
 * Inputs to propose function in Governor.sol
 * targets - a list of addresses on which proposed functions will be called
 * values - a list of values to send with each target transaction
 * calldatas - the bytes data representing each transaction and the arguments to pass proposed function calls
 * description - a description of what the proposal does/accomplishes
 *
 * The proposal function takes these inputs and will hash them, generating a unique proposalId.
 *
 * Another integral function within this contract is execute which we see takes largely the same parameters as propose. Within execute,
 * these passed parameters are hashed to determine the valid proposalId to execute. Some checks are performed before the internal _execute
 * is called and we can see the same low-level functionality we used to call arbitrary functions.
 *
 * _castVote: There are a number of derivated such as castVoteWithReason, castVoteBySig etc, but ultimately they boil down to this _castVote logic.
 * This function is fairly simple, it references the proposal via the passed proposalId, determines a voting weight with _getVotes, then adds the votes to an internal count of votes for that proposal, finally emitting an event.
 */

/**
 * @notice Other imports
 *
 * GovernorVotes.sol: This contract extracts voting weight from the ERC20 tokens used for a protocols governance.
 *
 * GovernorSettings.sol: An extension contract that allows configuration of things like voting delay, voting period and proposalThreshold to the protocol.
 *
 * GovernorCountingSimple.sol: This extension implements a simplified vote counting mechanism by which each proposal is assigned a ProposalVote struct in which forVotes, againstVotes and abstainVotes are tallied.
 *
 * GovernorVotesQuorumFraction: An extension which assists in token voting weight extraction.
 */

/**
 * @notice GovernorTimelockControl.sol:
 *
 * This is actually quite an important implementation and every DAO should employ a Timelock Controller. Effectively the Timelock controller is going to serve as a regulator for the Governor.
 * Each time the Governor control attempts to take an action, it will need to be checked versus the Timelock controller to account to cooldown periods, or voting delays.
 *
 * This functionality is important for a number of reasons, two major ones that come to mind are:
 *
 * Security - delays between successful votes and proposal execution afford the protocol/community time to assure there was no malicious code
 *
 * Fairness - this affords anyone who disagrees with a successful proposal time to exit their position on the protocol
 */
contract BoxGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    constructor(IVotes _token, TimelockController _timelock)
        Governor("BoxGovernor")
        GovernorSettings(1, /* 1 block */ 50400, /* 1 week */ 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {}

    // The following functions are overrides required by Solidity.

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
