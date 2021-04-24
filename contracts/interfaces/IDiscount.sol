pragma solidity ^0.5.16;

interface IDiscount {
    function getDiscount(address dfxToken, address userAddress) view external returns(uint256);
}