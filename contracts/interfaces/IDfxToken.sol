pragma solidity ^0.5.16;

interface IDfxToken {
    function balanceOfStaked(address account) external view returns (uint);
    function totalSupply() external view returns (uint256);

    function __addLockedBalance(address user, uint lockedAmount) external;
    function __updateLockedBalance(address user) external;
}