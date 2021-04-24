pragma solidity ^0.5.17;

interface IUniswap {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}