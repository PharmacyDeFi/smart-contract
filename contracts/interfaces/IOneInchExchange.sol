pragma solidity ^0.5.16;

interface IOneInchExchange {
    function spender() external view returns (address);
}