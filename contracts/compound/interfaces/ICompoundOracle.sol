pragma solidity ^0.5.16;

interface ICompoundOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}
