//SPDX-License-Identifier: MIT

// narrow down way we call functions

import {Test, console} from "../../lib/forge-std/src/Test.sol";
//import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
//import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

pragma solidity ^0.8.28;

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // means 100% more collateral needed (for 100 eth you get 50 eth worth of DSC)
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;
    //MockV3Aggregator ethUsdPriceFeed;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        //ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure override returns (uint256 result) {
        result = _bound(x, min, max); // Call the internal _bound function without logging
    }

    function mintDsc(uint256 amountDsc, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            console.log("No users with collateral deposited");
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);

        int256 maxDscForMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscForMint < 0) {
            return;
        }

        // console.log("maxDscForMint: ", maxDscForMint);
        // console.log("amountDsc: ", amountDsc);

        amountDsc = bound(amountDsc, 0, uint256(maxDscForMint));
        if (amountDsc == 0) {
            return;
        }

        vm.startPrank(sender);
        dscEngine.mintDsc(amountDsc);
        vm.stopPrank();
        timesMintIsCalled++;
        console.log("timesMintIsCalled: ", timesMintIsCalled);
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
        if (amountCollateral == 0) {
            return;
        }

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToReedem = dscEngine.getCollaterallBalanceOfUser(address(collateral), msg.sender);
        // console.log("maxCollateralToReedem: ", maxCollateralToReedem);
        // console.log("amountCollateral: ", amountCollateral);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToReedem);
        if (amountCollateral == 0) {
            return;
        }

        // Check health factor before redeeming
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(msg.sender);
        uint256 collateralValueAfterRedemption =
            collateralValueInUsd - dscEngine.getUsdValue(address(collateral), amountCollateral);
        uint256 healthFactorAfter = totalDscMinted == 0
            ? type(uint256).max
            : (collateralValueAfterRedemption * LIQUIDATION_THRESHOLD * 1e18) / (LIQUIDATION_PRECISION * totalDscMinted);
        if (healthFactorAfter < 1e18) {
            return; // Skip redemption if it breaks health factor
        }

        vm.startPrank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    // breaks the invariant because price plummets too quickly
    // function updateCollateralPrice(uint96 price) public {
    //     int256 newPriceInt = int256(uint256(price));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    //Helper function
    function _getCollateralFromSeed(uint256 collateralSeec) private view returns (ERC20Mock) {
        if (collateralSeec % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
