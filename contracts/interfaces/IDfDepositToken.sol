pragma solidity ^0.5.16;

interface IDfDepositToken {

    function mint(address account, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

    function balanceOfAt(address account, uint256 snapshotId) external view returns(uint256);
    function totalSupplyAt(uint256 snapshotId) external view returns(uint256);
    function totalSupply() external view returns(uint256);
    function snapshot() external returns(uint256);

}
