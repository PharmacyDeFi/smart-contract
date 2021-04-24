pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../deposits/DfTokenizedDeposit.sol";


contract DfTokenizedTest is DfTokenizedDeposit {

    uint public curBlockNumber = (START_BLOCK_1 - 1);

    function setBlockNumber(uint32 _curBlockNumber) public {
        curBlockNumber = _curBlockNumber;
    }

    // overridden function
    function _getBlockNumber() internal view returns(uint) {
        return curBlockNumber;
    }
}