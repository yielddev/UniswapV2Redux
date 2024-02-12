// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;
import {ERC20} from "@openzeppelin/contracts@v5.0.0/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts@v5.0.0/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    constructor(address _owner) Ownable(_owner) ERC20("MOCK", "MOCK") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}