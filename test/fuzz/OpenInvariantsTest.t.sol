// //SPDX-License-Identifier: MIT

// // have our invariants aka properties

// //What are our invarionts?
// // 1. The total supply of DSC should allways be less than total value of collateral
// // 2. Getter view should never revert <- evergreen invariant

// import {Test} from "../../lib/forge-std/src/Test.sol";
// import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// pragma solidity ^0.8.28;

// contract OpenInvariantTest is StdInvariant {
//     DeployDSC public deployDSC;
//     DSCEngine public dscEngine;
//     DecentralizedStableCoin dsc;

//     address weth;
//     address wbtc;
//     HelperConfig helperConfig;

//     function setUp() external {
//         deployDSC = new DeployDSC();
//         (dsc, dscEngine, helperConfig) = deployDSC.run();

//         (,,, weth, wbtc,) = helperConfig.activeNetworkConfig();

//         targetContract(address(dscEngine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         //get the value of all the collateral in protocol
//         //compare it to all debt (dsc)

//         uint256 totalDscDeposite = dsc.totalSupply();
//         uint256 totalWethDeposite = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 totalWbtcDeposite = IERC20(wbtc).balanceOf(address(dscEngine));

//         uint256 wethUSDValue = dscEngine.getUsdValue(weth, totalWethDeposite);
//         uint256 wbtcUSDValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposite);

//         assert(totalDscDeposite <= wethUSDValue + wbtcUSDValue);
//     }
// }
