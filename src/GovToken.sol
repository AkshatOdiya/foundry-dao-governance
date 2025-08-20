// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @notice ERC20Votes:
 *
 * ERC20Votes is "Compound-like" in how it implementing voting and delegation. It does a number of import things such as:
 *
 * Keeps a checkpoint history of each account's voting power. Using snapshots of voting power is important, as assessing realtime voting power is susceptible to exploitation!
 *
 * Any time a token is bought, or transferred checkpoints are typically updated in a mapping with the user addresses involved
 *
 * Allows the delegation of voting power to another entity while retaining possession of the tokens
 */
contract GovToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("DogeshBhaiToken", "DAWG") ERC20Permit("DogeshBhaiToken") {}

    // You probably don't want a function that anyone can call in order to mint your governance token, we're just applying this here to make our testing easier.
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
