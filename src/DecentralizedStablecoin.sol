// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// 100% controled by logic (the owner is the DSCEngine)
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


/*
* @title Decentralized Stable Coin
* @author tomo
* Colateral: Exogenous (ETH & BTC)
* Minting: Algorithmic
* Relative Stability: Pegged to USD
*
* This is the contract meant to be governed by a DSCEngine. This contract is just the ERC20 impelemntation of our stablecoin system.
*/
contract DecentralizedStableCoin is ERC20Burnable, Ownable {

    error DecentralizedStableCoin__MustBeMoretThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() Ownable(msg.sender) ERC20("DecentralizedStableCoin", "DSC") {
       //_owner = initialOwner;

    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoretThanZero();
        }

        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }

        //this means use the function from the parent contract (ERC20Burnable)
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {

        if(_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }

        if(_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoretThanZero();
        }

        _mint(_to, _amount);

        return true;
    }
}