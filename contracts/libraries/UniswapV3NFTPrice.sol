// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapV3NFTPrice {
    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Factory public uniswapV3Factory;

    mapping(address => address) public priceFeeds;

    constructor(address  _positionManager) {
        positionManager = INonfungiblePositionManager(_positionManager); 
        uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        priceFeeds[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // WETH/USD
        priceFeeds[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC/USD
    }

    function getLPTokenValue(uint256 tokenId) external view returns (uint256 totalValue) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,
            
        ) = positionManager.positions(tokenId);
        address poolAddress = uniswapV3Factory.getPool(token0, token1, fee);
        require(poolAddress != address(0), "Pool does not exist");

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        uint160 sqrtRatioAX96 = _getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = _getSqrtRatioAtTick(tickUpper);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity
        );

        uint256 token0PriceInUSD = getTokenPriceInUSD(token0);
        uint256 token1PriceInUSD = getTokenPriceInUSD(token1);

        uint256 token0Value = amount0 * token0PriceInUSD;
        uint256 token1Value = amount1 * token1PriceInUSD;

        totalValue = token0Value + token1Value;
        return totalValue;
    }

    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    function currentPoolPrice(uint160 sqrtPriceX96) external pure returns (uint256) {
        return (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) * 1e18 >> (96 * 2);
    }

    function getTokenPriceInUSD(address token) public view returns (uint256) {

        address priceFeedAddress = priceFeeds[token];
        require(priceFeedAddress != address(0), "Price feed not available");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);

        (
            ,
            int price,
            ,
            ,
        ) = priceFeed.latestRoundData();

        return uint256(price) * 1e10;
    }

    function setPriceFeed(address token, address priceFeed) external {
        priceFeeds[token] = priceFeed;
    }
}