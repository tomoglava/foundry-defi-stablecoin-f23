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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DSCEngine
 * @author tomo
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stablecon has the properties of being:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically stable
 *
 * It is simmilar to DAI if DAI had no governance, no feesm and was only backed by WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed value of all DSC.
 * @notice This contract is the core of the DSC system. It handles all the logic for mining and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is very loosley based on the MakerDAO DSS (DAI) system.
 *
 */
contract DSCEngine is ReentrancyGuard {
    /////////////////////
    // Errors          //
    /////////////////////
    error DSCEngine__MustBeMoretThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressMismatch();
    error DSCEngine__TokenNotSupported();
    error DSCEngine__DepositCollateralFailed();

    /////////////////////
    // State Variables //
    /////////////////////
    // for example token address of AAVE => price feed address of AAVE (can be uniswap, chainlink...)
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscminted) private s_DscMinted;

    DecentralizedStableCoin public immutable i_dsc;

    /////////////////////
    // Events          //
    /////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    /////////////////////
    // Modifiers      //
    /////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoretThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotSupported();
        }
        _;
    }

    /////////////////////
    // Functions      //
    /////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        // USD price feeds
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressMismatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////////
    // External Functions     //
    ////////////////////////////

    function depositCollateralAndMintDsc() external {}

    /*
     * @notice Follows CEI pattern (Check-Effect-Interact)
     * @param tokencollaterallAddress The address of the token to be used as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokencollaterallAddress, uint256 amountCollateral)
        external
        // checks
        moreThanZero(amountCollateral)
        isAllowedToken(tokencollaterallAddress)
        nonReentrant
    {
        // effects
        s_collateralDeposited[msg.sender][tokencollaterallAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokencollaterallAddress, amountCollateral);

        // interacts
        bool success = IERC20(tokencollaterallAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__DepositCollateralFailed();
        }
    }

    function redeemColateralForDsc() external {}

    // Threshold to let's say 150%
    // you can drop from to $100 ETH -> $74 ETH (UNDERCOLLATERALIZED!)
    // to mint $50 DSC
    // HEY, if someone pays back your minted DSC, they can have all your collateral for a discount
    // somebody can pay $50 to get yours $74 worth ETH
    function redeemCollateral() external {}

    /*
     * @notice This function is called by the DSCEngine to mint DSC
     * @param amountDscToMint The amount of DSC to mint
     * @notice they must have more collateral than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {}

    function burnDsc() external {}

    function liquidate() external {}

    function gethHealthFactor() external view {}

    ////////////////////////////////////////
    // Private and Internal Functions     //
    ////////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalAmountMinted, uint256 collateralValueInUsd)
    {}

    /*
     * @notice This function is called by the DSCEngine to mint DSC
     * @param amountDscToMint The amount of DSC to mint
     * @notice returns how close user is to liquidation (if user is bellow 1 they can be liquidated)
     */

    function _healthFactor(address user) private view returns (uint256) {}

    function _revertIfHealthFactorIsBroken() internal view {
        //1. check health factor (do they have enough collateral)
        //2. if not, revert
    }
}
