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


/*
* @title Decentralized Stable Coin
* @author tomo
* Colateral: Exogenous (ETH & BTC)
* Minting: Algorithmic
* Relative Stability: Pegged to USD
*
* This is the contract meant to be governed by a DSCEngine. This contract is just the ERC20 impelemntation of our stablecoin system.
*/
contract DecentralizedStableCoin {

    constructor() {
        // constructor
    }

}