pragma solidity ^0.5.16;
import "../interfaces/IDfxToken.sol";

contract DfDiscount {
    function getDiscount(IDfxToken dfxToken, address userAddress) view public returns(uint256) {
        uint256 amount = dfxToken.balanceOfStaked(userAddress) / 1e18;

        if (amount >= 25000) {          // 25,000 – 95%
            return 95;
        } else if (amount >= 2500) {    // 2,500 – 75%
            return 75;
        } else if (amount >= 250) {     // 250 – 50%
            return 50;
        } else if (amount >= 50) {      // 50 – 25%
            return 25;
        }

        return 0;
    }
}