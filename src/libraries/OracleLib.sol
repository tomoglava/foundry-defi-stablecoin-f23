//SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

/**
 * @title OracleLib
 * @author Tomo
 * @notice This librari is used to check Chainlink Oracle for stale data.
 * If a price is stale (doesn't change for a period of time Chainlik says it should), the function will revert and render the DSCEndgine unusable. This is by design.
 * We want DSCEngine to freeze if the price is stale.
 * So if Chainlink Oracle is down, the system will freeze and lot of money stays locked in protocol.
 * @dev Library for getting oracle price
 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 seconds

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundID, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSinceUpdate = block.timestamp - updatedAt;
        if (secondsSinceUpdate > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        return (roundID, answer, startedAt, updatedAt, answeredInRound);
    }
}
