pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./PhaD.sol";
import "../interfaces/IDfTokenizedDepositsDevs_v2.sol";

import "../utils/DSMath.sol";


contract PhaDstake is
    Initializable,
    DSMath,
    Pharmacy
{

    struct StakedBalance {
        uint96 balance;
        uint96 pendingBalance;
        uint32 unstakedTimestamp;
    }
    mapping (address => StakedBalance) public stakedBalances;

    struct LockedBalance {
        uint96 locked;
        uint32 fromBlock;
    }
    mapping (address => LockedBalance) public lockedBalances;   // locked balances (from phad distribution stage 1)


    uint32 public constant UNSTAKED_TIME = 1 days;

    address public constant DF_TOKENIZED_DEPOSITS = address(0); // TODO:
    uint32 public constant FIRST_STAGE_END_BLOCK = 0;           // TODO:

    uint256 public constant HUNDRED_APY_PER_BLOCK = 475650000000;   // 100 APY
    uint256 public constant DEFAULT_UNLOCK_APY = 0.015 * 1e18;      // 1.5 APY


    event TokensStaked(address indexed account, uint256 amount);
    event TokensUnstaked(address indexed account, uint256 amount);
    event TokensClaimed(address indexed account, uint256 amount);
    event TokensLocked(address indexed account, uint256 amount);
    event TokensUnlocked(address indexed account, uint256 amount);


    modifier enoughTransferable(address sender, uint amount) {
        require(amount <= balanceOfTransferable(sender), "Insufficient amount of transferable tokens");
        _;
    }


    /**
     * @notice Initialize a new Pharmacy
     * @param account The initial account to grant all the tokens
     */
    function initialize(address account) public initializer {
        // Initialize Parent Contract
        Pharmacy.initialize(account);
    }


    // ** PUBLIC VIEW BalanceOf functions **

    function balanceOfStaked(address account) public view returns (uint) {
        uint96 stakedBalance = stakedBalances[account].balance;
        uint96 pendingBalance = stakedBalances[account].pendingBalance;

        if (stakedBalance <= pendingBalance) {
            return 0;
        }

        return sub96(stakedBalance, pendingBalance, "balanceOfStaked: amount exceeds balance");
    }

    function balanceOfPending(address account) public view returns (uint) {
        return stakedBalances[account].pendingBalance;
    }

    function balanceOfUnlocked(address account) public view returns (uint) {
        LockedBalance memory lockedBalance = lockedBalances[account];

        uint curBlock = _getBlockNumber();
        if (lockedBalance.locked == 0 || lockedBalance.fromBlock >= curBlock) {
            return 0;
        }

        uint duration = sub(curBlock, lockedBalance.fromBlock);

        uint multiplier = add(DEFAULT_UNLOCK_APY, getStakeMultiplier(account));
        multiplier = add(multiplier, getLiquidityMultiplier(account));

        uint unlockedPercent = mul(wmul(duration, multiplier), HUNDRED_APY_PER_BLOCK);
        uint unlockedTokens = wmul(lockedBalance.locked, unlockedPercent);

        return (unlockedTokens > lockedBalance.locked) ? lockedBalance.locked : unlockedTokens;
    }

    function balanceOfLocked(address account) public view returns (uint) {
        return sub(lockedBalances[account].locked, balanceOfUnlocked(account));
    }

    function balanceOfTransferable(address account) public view returns (uint) {
        // sub total balance of staked with pending (staked + pending tokens)
        uint96 accBalance = sub96(balances[account], stakedBalances[account].balance, "balanceOfTransferable: amount exceeds balance");
        return sub96(accBalance, uint96(balanceOfLocked(account)), "balanceOfTransferable: amount exceeds balance");
    }


    // ** PUBLIC VIEW Multiplier functions **

    function getStakeMultiplier(address account) public view returns (uint) {
        uint stakedAmount = balanceOfStaked(account) / 1e18;

        if (stakedAmount        >= 250000) {   // 250k - +50 APY of locked PhaD
            return 0.50 * 1e18;
        } else if (stakedAmount >= 50000) {    // 50k - +45 APY of locked PhaD
            return 0.45 * 1e18;
        } else if (stakedAmount >= 25000) {    // 25k - +42.5 APY of locked PhaD
            return 0.425 * 1e18;
        } else if (stakedAmount >= 10000) {    // 10k - +40 APY of locked PhaD
            return 0.40 * 1e18;
        } else if (stakedAmount >= 5000) {     // 5k - +35 APY of locked PhaD
            return 0.35 * 1e18;
        } else if (stakedAmount >= 2500) {     // 2.5k - +30 APY of locked PhaD
            return 0.30 * 1e18;
        } else if (stakedAmount >= 500) {      // 0.5k - +25 APY of locked PhaD
            return 0.25 * 1e18;
        } else if (stakedAmount >= 250) {      // 0.25k - +20 APY of locked PhaD
            return 0.20 * 1e18;
        } else if (stakedAmount >= 50) {       // 50 - +1.5 APY of locked PhaD
            return 0.015 * 1e18;
        }

        return 0;
    }

    function getLiquidityMultiplier(address account) public view returns (uint) {
        uint curLiquidity = IDfTokenizedDeposits(DF_TOKENIZED_DEPOSITS).balanceOf(account);
        uint initLiquidity = IDfTokenizedDeposits(DF_TOKENIZED_DEPOSITS).firstStageMaxLiquidity(account);

        // exit
        if (initLiquidity == 0 || curLiquidity == 0) {
            return 0;
        }

        uint ratio = wdiv(curLiquidity, initLiquidity);

        if (ratio        >= 2.0 * 1e18) {   // x2.0 - +50 APY of locked PhaD
            return 0.50 * 1e18;
        } else if (ratio >= 1.5 * 1e18) {   // x1.5 - +37.5 APY of locked PhaD
            return 0.375 * 1e18;
        } else if (ratio >= 1.0 * 1e18) {   // x1.0 - +25 APY of locked PhaD
            return 0.25 * 1e18;
        } else if (ratio >= 0.5 * 1e18) {   // x0.5 - +12.5 APY of locked PhaD
            return 0.125 * 1e18;
        } else if (ratio >= 0.4 * 1e18) {   // x0.4 - +10 APY of locked PhaD
            return 0.10 * 1e18;
        } else if (ratio >= 0.3 * 1e18) {   // x0.3 - +7.5 APY of locked PhaD
            return 0.075 * 1e18;
        } else if (ratio >= 0.2 * 1e18) {   // x0.2 - +5 APY of locked PhaD
            return 0.05 * 1e18;
        } else if (ratio >= 0.1 * 1e18) {   // x0.1 - +2.5 APY of locked PhaD
            return 0.025 * 1e18;
        }

        return 0;
    }


    // ** PUBLIC functions **

    function stake(uint rawAmount) public {
        uint96 amount = safe96(rawAmount, "stake: amount exceeds 96 bits");

        address account = msg.sender;
        require(amount <= balanceOfTransferable(account), "Not enough tokens");

        // update locked balance
        _updateLockedBalance(account);

        // Withdraw dai and phad profit
        IDfTokenizedDeposits(DF_TOKENIZED_DEPOSITS).withdrawProfit(account);

        // UPD StakedBalance state
        stakedBalances[account].balance = add96(stakedBalances[account].balance, amount, "stake: amount overflows");

        emit TokensStaked(account, amount);
    }

    function unstake(uint rawAmount) public {
        uint96 amount = safe96(rawAmount, "unstake: amount exceeds 96 bits");

        address account = msg.sender;

        require(amount <= stakedBalances[account].balance, "Invalid staked token amount");

        // update locked balance
        _updateLockedBalance(account);

        // Withdraw dai and phad profit
        IDfTokenizedDeposits(DF_TOKENIZED_DEPOSITS).withdrawProfit(account);

        // UPD StakedBalance state
        stakedBalances[account].pendingBalance = amount;
        stakedBalances[account].unstakedTimestamp = uint32(block.timestamp);

        emit TokensUnstaked(account, amount);
    }

    function claimUnstaked() public {
        address account = msg.sender;
        uint96 unstakedTimestamp = uint96(stakedBalances[account].unstakedTimestamp);
        require(
            unstakedTimestamp > 0 &&
            sub96(uint96(block.timestamp), unstakedTimestamp, "claimUnstaked: too small block.timestamp") > UNSTAKED_TIME,
            "claimUnstaked: withdrawal time has not yet come"
        );

        uint96 amount = stakedBalances[account].pendingBalance;

        // UPD StakedBalance state
        stakedBalances[account].balance = sub96(stakedBalances[account].balance, amount, "claimUnstaked: amount exceeds balance");
        stakedBalances[account].pendingBalance = 0;
        stakedBalances[account].unstakedTimestamp = 0;

        emit TokensClaimed(account, amount);
    }


    // ** only DfTokenizedDeposits functions **

    // call this function after 1 stage PhaD distribution in Tokenized
    function __addLockedBalance(address user, uint lockedAmount) public {
        require(msg.sender == DF_TOKENIZED_DEPOSITS, "Permission denied");

        uint96 amount = safe96(lockedAmount, "locked: amount exceeds 96 bits");

        LockedBalance storage lockedBalance = lockedBalances[user];
        lockedBalance.locked = add96(lockedBalance.locked, amount, "locked: amount overflows");
        lockedBalance.fromBlock = FIRST_STAGE_END_BLOCK;

        emit TokensLocked(user, lockedAmount);
    }

    // call this function from deposit & withdraw in Tokenized
    function __updateLockedBalance(address user) public {
        require(msg.sender == DF_TOKENIZED_DEPOSITS, "Permission denied");
        _updateLockedBalance(user);
    }


    // ** INTERNAL VIEW functions **

    function _getBlockNumber() internal view returns(uint) {
        return block.number;
    }


    // ** INTERNAL functions **

    function _transferTokens(address src, address dst, uint96 amount) internal enoughTransferable(src, amount) {
        super._transferTokens(src, dst, amount);
    }

    function _updateLockedBalance(address account) internal {
        LockedBalance storage lockedBalance = lockedBalances[account];

        // exit
        if (lockedBalance.locked == 0) {
            return;
        }

        uint unlockedBalance = balanceOfUnlocked(account);
        lockedBalance.locked = sub96(lockedBalance.locked, uint96(unlockedBalance), "_updateLockedBalance: amount exceeds balance");
        lockedBalance.fromBlock = safe32(_getBlockNumber(), "_updateLockedBalance: block number exceeds 32 bits");

        emit TokensUnlocked(account, unlockedBalance);
    }
}
