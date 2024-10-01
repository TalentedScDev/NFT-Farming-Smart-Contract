// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TERACToken is ERC20, Ownable{

    constructor(
        address initialOwner,
        uint256 initialSupply
    ) ERC20("TERAC", "TERAC") Ownable(initialOwner) {
        _mint(initialOwner, initialSupply * 10 ** decimals());
    }
}