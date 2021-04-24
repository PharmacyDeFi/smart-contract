pragma solidity ^0.5.16;

import "../dfxToken/DfxTokenStakable.sol";


contract DfxTest is DfxTokenStakable {

    uint public curBlockNumber = (FIRST_STAGE_END_BLOCK - 1);

    function setBlockNumber(uint32 _curBlockNumber) public {
        curBlockNumber = _curBlockNumber;
    }

    // overridden function
    function _getBlockNumber() internal view returns(uint) {
        return curBlockNumber;
    }
}