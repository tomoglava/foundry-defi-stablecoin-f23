// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    HelperConfig.Network network;
    DeployDSC deployDSC;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    int256 public ethPrice;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, engine, helperConfig) = deployDSC.run();
        (ethPrice, ethUsdPriceFeed,, weth,,) = helperConfig.activeNetworkConfig();

        console.log("ethPrice: %d", ethPrice);

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////////
    // Price tests          //
    //////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000e8 / 1e8 = 30000e18

        uint256 expectedUsdValue = uint256(ethPrice) * ethAmount / 1e8;

        uint256 actualUsdValue = engine.getUsdValue(weth, ethAmount);
        assertEq(actualUsdValue, expectedUsdValue);
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

    ///////////////////////////////
    // Allowing token tests      //
    ///////////////////////////////

    function testRevertIfTokenNotSupported() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__TokenNotSupported.selector);
        engine.depositCollateral(makeAddr("notSupportedToken"), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
}
