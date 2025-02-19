// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployDSC;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE_WETH = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE_WBTC = 10 ether;

    int256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    int256 public ethPrice;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, engine, helperConfig) = deployDSC.run();
        (ethPrice, ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();

        ethPrice = ethPrice * ADDITIONAL_FEED_PRECISION;

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE_WETH);
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE_WBTC);
    }

    //////////////////////////
    // Construction tests   //
    //////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoenstMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressMismatch.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////////
    // Modifier tests       //
    //////////////////////////

    //////////////////////////
    // Price tests          //
    //////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;

        uint256 expectedUsdValue = uint256(ethPrice) * ethAmount;
        uint256 actualUsdValue = engine.getUsdValue(weth, ethAmount) * PRECISION;

        assertEq(actualUsdValue, expectedUsdValue);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
    }

    //////////////////////////////////
    // Deposit collateral tests     //
    //////////////////////////////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoretThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    // works only on anvil
    // function testWhenCollateralMoreThanZero() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

    //     engine.depositCollateral(weth, AMOUNT_COLLATERAL);

    //     uint256 userCollateralBalance = engine.getAccountCollateralOfToken(USER, weth);
    //     assertEq(userCollateralBalance, AMOUNT_COLLATERAL);

    //     vm.stopPrank();
    // }

    function testRevertIfCollateralNotApproved() public {
        ERC20Mock ranToken = new ERC20Mock("RAND", "RAND", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__TokenNotSupported.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral_WETH() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateral_WBTC() {
        vm.startPrank(USER);
        ERC20Mock(wbtc).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(wbtc, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositCollateral_WETH_AndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 9e21);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral_WETH {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // function testDepositCollateralAndMintDsc() public depositedCollateral {
    //     uint256 dscAmount = 1000;
    //     engine.mintDsc(dscAmount);

    //     address USER2 = makeAddr("user");
    //     vm.startPrank(USER2);
    //     ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
    //     engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, dscAmount);
    //     vm.stopPrank();

    //     (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
    //     (uint256 totalDscMinted2, uint256 collateralValueInUsd2) = engine.getAccountInformation(USER2);

    //     assertEq(totalDscMinted, totalDscMinted2);
    //     assertEq(collateralValueInUsd, collateralValueInUsd2);
    // }

    ///////////////////////////////////
    // Mint DSC tests                //
    ///////////////////////////////////

    function testRevertIfDscAmountZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoretThanZero.selector);
        engine.mintDsc(0);
    }

    // function testRevertIfThereIsNoCollateralEgHealthBroken() public {
    //     uint256 dscAmount = 1000;
    //     vm.startPrank(USER);

    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorBroken.selector);
    //     engine.mintDsc(dscAmount);

    //     vm.stopPrank();
    // }

    function testRevertIfThereIsNoCollateralEgHealthBroken() public {
        uint256 dscAmount = 1000;
        vm.startPrank(USER);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorBroken.selector, 0));
        engine.mintDsc(dscAmount);

        vm.stopPrank();
    }

    //////////////////////////////////
    // Account information tests    //
    //////////////////////////////////

    function testGetAccountCollateralValueInUsd() public depositedCollateral_WBTC depositedCollateral_WETH {
        vm.startPrank(USER);
        uint256 expectedCollateralValueInUsd =
            engine.getUsdValue(weth, AMOUNT_COLLATERAL) + engine.getUsdValue(wbtc, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 actualCollateralValueInUsd = engine.getAccountCollateralValueInUsd(USER);

        assertEq(expectedCollateralValueInUsd, actualCollateralValueInUsd);
    }

    function testGetAccountCollateralOfToken() public depositedCollateral_WETH {
        uint256 actualCollateral = engine.getAccountCollateralOfToken(USER, weth);
        assertEq(AMOUNT_COLLATERAL, actualCollateral);
    }

    //////////////////////////////////
    // Redeem collateral tests      //
    //////////////////////////////////

    function testRevertIfRedeemAmountZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoretThanZero.selector);
        engine.redeemCollateral(weth, 0);
    }

    function testExpectedUsdValueAfterRedeemMintAndBurnSuccess() public depositCollateral_WETH_AndMintDsc {
        uint256 redeemAmount = 2 ether;

        vm.startPrank(USER);
        uint256 expectedCollateralValueInUsd = engine.getUsdValue(weth, (AMOUNT_COLLATERAL - redeemAmount));

        //ERC20Mock(weth).approve(address(engine), redeemAmount);
        DecentralizedStableCoin(address(engine.i_dsc())).approve(address(engine), 200);
        engine.redeemColateralForDsc(weth, redeemAmount, 200);
        vm.stopPrank();

        uint256 actualCollateralValueInUsd = engine.getAccountCollateralValueInUsd(USER);
        assertEq(expectedCollateralValueInUsd, actualCollateralValueInUsd);
    }

    ////////////////////////////
    // Liquidation tests      //
    ////////////////////////////

    function testRevertIfLiquidationAmountZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoretThanZero.selector);
        engine.liquidate(weth, USER, 0);
    }

    function testRevertIfHealthFactorIsOK() public depositCollateral_WETH_AndMintDsc {
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOK.selector);
        engine.liquidate(weth, USER, 1e21);
    }

    // function testIfHealthFactorIsntImprovedAfterLiquidation() public depositCollateral_WETH_AndMintDsc {
    //     vm.prank(USER);
    //     uint256 startingUserHealthFactor = engine.gethHealthFactor();
    //     console.log("initialHealthFactor", startingUserHealthFactor);
    //     (uint256 totalDscMintedBefore, uint256 collateralValueInUsBefore) = engine.getAccountInformation(USER);
    //     console.log("totalDscMintedBefore", totalDscMintedBefore);
    //     console.log("collateralValueInUsBefore", collateralValueInUsBefore);

    //     helperConfig.updateETHPrice(1e17);

    //     vm.prank(USER);
    //     uint256 healthFactorAfterPriceDropped = engine.gethHealthFactor();
    //     console.log("expectedHealthFactor", healthFactorAfterPriceDropped);
    //     (uint256 totalDscMintedAfter, uint256 collateralValueInUsdAfter) = engine.getAccountInformation(USER);
    //     console.log("totalDsctotalDscMintedAfterMinted", totalDscMintedAfter);
    //     console.log("collateralValueInUsdAfter", collateralValueInUsdAfter);

    //     address liquidatorAddress = makeAddr("liquidator");
    //     vm.startPrank(liquidatorAddress);
    //     ERC20Mock(weth).mint(liquidatorAddress, 1e30);
    //     DecentralizedStableCoin(address(engine.i_dsc())).approve(address(engine), 1e21);
    //     engine.depositCollateralAndMintDsc(weth, 1e20, 1e22);
    //     engine.liquidate(weth, USER, 1e21);
    //     vm.stopPrank();

    //     vm.prank(USER);
    //     uint256 healthFactorAfterLiquidation = engine.gethHealthFactor();
    //     console.log("expectedHealthFactor", healthFactorAfterLiquidation);
    // }

    function testIfHealthFactorIsntImprovedAfterLiquidation() public depositCollateral_WETH_AndMintDsc {
        
        //drops price and healthFactor drops below 1e18
        helperConfig.updateETHPrice(1e17);
            
        vm.prank(USER);
        uint256 startingUserHealthFactor = engine.gethHealthFactor();
        console.log("initialHealthFactor", startingUserHealthFactor);
        (uint256 totalDscMintedBefore, uint256 collateralValueInUsBefore) = engine.getAccountInformation(USER);
        console.log("totalDscMintedBefore", totalDscMintedBefore);
        console.log("collateralValueInUsBefore", collateralValueInUsBefore);

        address liquidatorAddress = makeAddr("liquidator");
        vm.startPrank(liquidatorAddress);
        ERC20Mock(weth).mint(liquidatorAddress, 1e30);
         // Approve DSCEngine to spend WETH
        ERC20Mock(weth).approve(address(engine), 1e25);
        DecentralizedStableCoin(address(engine.i_dsc())).approve(address(engine), 1e21);
        engine.depositCollateralAndMintDsc(weth, 1e25, 1e22);
        engine.liquidate(weth, USER, 1e21);
        vm.stopPrank();

        vm.prank(USER);
        uint256 healthFactorAfterLiquidation = engine.gethHealthFactor();
        console.log("healthFactorAfterLiquidation", healthFactorAfterLiquidation);

        (uint256 totalDscMintedAfter, uint256 collateralValueInUsdAfter) = engine.getAccountInformation(USER);
        console.log("totalDsctotalDscMintedAfterMinted", totalDscMintedAfter);
        console.log("collateralValueInUsdAfter", collateralValueInUsdAfter);
        
        // assertLe(healthFactorAfterLiquidation, startingUserHealthFactor, "reason");
    }
}
