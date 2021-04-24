pragma solidity ^0.5.16;

interface IDfTokenizedDeposits {
    function balanceOf(address account) external view returns(uint);
    function firstStageMaxLiquidity(address account) external view returns(uint);

    function withdrawProfit(address userAddress) external;
}
