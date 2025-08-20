// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    /**
     * @notice Create a new Timelock controller
     * @param minDelay Minimum delay for timelock executions
     * @param proposers List of addresses that can propose new transactions
     * @param executors List of addresses that can execute transactions
     */
    // we're passing msg.sender to the TimelockController's admin parameter. We have to set an initial admin for the controller, but this can and should be changed after deployment
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
