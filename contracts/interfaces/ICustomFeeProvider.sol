pragma solidity ^0.5.16;

interface ICustomFeeProvider {
    function distFee(uint256 _compAmount, uint256 _comp_dai_Price, uint256 _comp_ether_Price) external;
}