pragma solidity ^0.5.16;

interface IEtherPool {
    function payRefundForTrx(address payable _userAddress, uint64 gasAmount) external;
}
