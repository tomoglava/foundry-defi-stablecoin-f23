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

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    int256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    int256 public ethPrice;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, engine, helperConfig) = deployDSC.run();
        (ethPrice, ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();

        ethPrice = ethPrice * ADDITIONAL_FEED_PRECISION;

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
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

    function testGetTokenAmountFromUsd() public {
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

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
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
}
