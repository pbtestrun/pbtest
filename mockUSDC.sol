// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable, ERC20Permit {

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    constructor(address recipient, address owner)

        ERC20("mockUSDC", "mockUSDC")
        Ownable(owner)
        ERC20Permit("mockUSDC")
    {
        _mint(recipient, 5000000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}