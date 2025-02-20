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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__HealthFactorBroken(uint256 healthFactor);
    error DSCEngine__MintingFailed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNitImproved();

    /////////////////////
    // State Variables //
    /////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // means 100% more collateral needed (for 100 eth you get 50 eth worth of DSC)
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    // for example token address of AAVE => price feed address of AAVE (can be uniswap, chainlink...)
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    address[] private s_collateralTokens;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;

    DecentralizedStableCoin public immutable i_dsc;

    /////////////////////
    // Events          //
    /////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event DscMinted(address indexed user, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );

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
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////////
    // External Functions     //
    ////////////////////////////

    /*
     * @param amountDscToMint The amount of DSC to mint
     * @param amountCollateral The amount of collateral to deposit
     * @param tokenCollateralAddress The address of the token to be used as collateral
     * @notice this function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /*
     * @notice Follows CEI pattern (Check-Effect-Interact)
     * @param tokencollaterallAddress The address of the token to be used as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokencollaterallAddress, uint256 amountCollateral)
        public
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

    /*
     * @notice Follows CEI pattern (Check-Effect-Interact)
     * @param tokenCollateralAddress The collateral address to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountToBurnDsc The amount of DSC to burn
     * @notice This function burns DSC and redeems collateral in one transaction
     */

    function redeemColateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountToBurnDsc)
        external
    {
        burnDsc(amountToBurnDsc);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral check health factor
    }

    // Threshold to let's say 150%
    // you can drop from to $100 ETH -> $74 ETH (UNDERCOLLATERALIZED!)
    // to mint $50 DSC
    // HEY, if someone pays back your minted DSC, they can have all your collateral for a discount
    // somebody can pay $50 to get yours $74 worth ETH

    //in order to redeem collateral:
    // 1. health factor must be above 1 after collateral pulled
    // DRY: Don't repeat yourself
    // follow CEI if possible - probbably won't be possible

    /*
     * @notice Follows CEI pattern (Check-Effect-Interact)
     * @param tokenCollateralAddress The address of the token to be used as collateral
     * @param amountCollateral The amount of collateral to redeem
     * @notice health factor must be above 1 after collateral pulled
     * @notice we have to burn the DSC in order to have correct health factor, but before redeeming collateral
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice This function is called by the DSCEngine to mint DSC
     * @param amountDscToMint The amount of DSC to mint
     * @notice they must have more collateral than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DscMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC with $100 collateral) revert it
        // we could let them do it but it's not good for them, UX wise
        _revertIfHealthFactorIsBroken(msg.sender);

        bool success = i_dsc.mint(msg.sender, amountDscToMint);
        if (!success) {
            revert DSCEngine__MintingFailed();
        }

        emit DscMinted(msg.sender, amountDscToMint);
    }

    // Do we need to check if this breaks health factor? Probably not since removing a debt should increase health factor
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // probably not needed - good to ask auditors
    }

    //if we do start nearing undercollateralization, we need someone to liquidate positions
    /*
     * @notice This function is called by the DSCEngine to liquidate a position
     * @param collateral the erc20 collateral address to liquidate from the user
     * @param user The user who has broken health factor, eg. _healthFactor < MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the users health factor
     * @notice you cann partially liquidate user positions
     * @notice you will get a liquidation bonus fo taking the users funds
     * @notice this function working assumes the protocol will be roughly 200% overcollateralized in order for this to work
     * @notice a known bug would be if the protocol were 100% or less collateralized, then we wouldn't be able to incetive the liquidators
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateralAddress, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }

        //burn DSC
        //take collateral
        //bad user: $140 ETH and $100 DSC
        //debtToCover = $100
        //$100 of DSC == ?? ETH

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralAddress, debtToCover);

        // give 10% bonus to liquidator ($110 weth for $100 DSC)
        // we should implement a feature to liquidate in the event protocol is insolvent - we are not doing that here
        // and sweep extra mounts into a treasury - not gonna do that here

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateralAddress, totalCollateralToRedeem);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 engdingUserHealthFactor = _healthFactor(user);
        if (engdingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNitImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function gethHealthFactor() external view returns (uint256) {
        return _healthFactor(msg.sender);
    }

    ////////////////////////////////////////
    // Private and Internal Functions     //
    ////////////////////////////////////////

    /*
     * @dev Low-level internal function, do not call unless the function calling it is checking for health factor being broken
     * 
     */
    function _burnDsc(uint256 amountToBurn, address onBehalfOf, address dscFrom) private {
        s_DscMinted[onBehalfOf] -= amountToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountToBurn);
        //This conditional is hypothtically unreachable, but it's good to have it
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /*
     * @notice This function is called by the DSCEngine to mint DSC
     * @param amountDscToMint The amount of DSC to mint
     * @notice returns how close user is to liquidation (if user is bellow 1 they can be liquidated)
     */

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) {
            return type(uint256).max;
        } else {
            uint256 collateralAdjustedForThreshold =
                (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
            return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        }

        // $1000 eth mints 100 DSC
        // 1000 * 50 = 50000
        // 50000 / 100 = 500
        // 500 / 100 = 5 > 1

        //return collateralValueInUsd / totalDscMinted;
    }

    //1. check health factor (do they have enough collateral)
    //2. if not, revert
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorBroken(userHealthFactor);
        }
    }

    //////////////////////////////////////
    // Public & extermal view Functions //
    //////////////////////////////////////

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        //loop throall collateral tokens, get the amount they have deposited, and map it to the price, to get the USD value

        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // eth/usd and btc/usd on chainlink has 8 decimal places so:
        // it 1 eth = $1000
        // the returned value from chainlink will be 1000 * 10 ** 8 (it is 10 ** 8 = 10^8)

        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // usdAmount * 18 decimals / price_with_8_decimals * 10 decimals
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralOfToken(address user, address token) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getCollaterallBalanceOfUser(address token, address user) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }
}
