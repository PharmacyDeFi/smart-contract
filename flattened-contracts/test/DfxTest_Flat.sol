pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    address self = address(this);
    uint256 cs;
    assembly { cs := extcodesize(self) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

contract DfxToken is Initializable {
    /// @notice EIP-20 token name for this token
    string public constant name = "DeFireX";

    /// @notice EIP-20 token symbol for this token
    string public constant symbol = "DFX";

    /// @notice EIP-20 token decimals for this token
    uint8 public constant decimals = 18;

    /// @notice Total number of tokens in circulation
    uint public constant totalSupply = 10000000e18; // 10 million DFX

    /// @notice Allowance amounts on behalf of others
    mapping (address => mapping (address => uint96)) internal allowances;

    /// @notice Official record of token balances for each account
    mapping (address => uint96) internal balances;

    /// @notice A record of each accounts delegate
    mapping (address => address) public delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice The standard EIP-20 approval event
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /**
     * @notice Initialize a new DFX token
     * @param account The initial account to grant all the tokens
     */
    function initialize(address account) public initializer {
        balances[account] = uint96(totalSupply);
        emit Transfer(address(0), account, totalSupply);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender) external view returns (uint) {
        return allowances[account][spender];
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param rawAmount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint rawAmount) external returns (bool) {
        uint96 amount;
        if (rawAmount == uint(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(rawAmount, "approve: amount exceeds 96 bits");
        }

        allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint rawAmount) external returns (bool) {
        uint96 amount = safe96(rawAmount, "transfer: amount exceeds 96 bits");
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint rawAmount) external returns (bool) {
        address spender = msg.sender;
        uint96 spenderAllowance = allowances[src][spender];
        uint96 amount = safe96(rawAmount, "approve: amount exceeds 96 bits");

        if (spender != src && spenderAllowance != uint96(-1)) {
            uint96 newAllowance = sub96(spenderAllowance, amount, "transferFrom: transfer amount exceeds spender allowance");
            allowances[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "delegateBySig: invalid nonce");
        require(now <= expiry, "delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint96) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint96) {
        require(blockNumber < block.number, "getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint96 delegatorBalance = balances[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _transferTokens(address src, address dst, uint96 amount) internal {
        require(src != address(0), "_transferTokens: cannot transfer from the zero address");
        require(dst != address(0), "_transferTokens: cannot transfer to the zero address");

        balances[src] = sub96(balances[src], amount, "_transferTokens: transfer amount exceeds balance");
        balances[dst] = add96(balances[dst], amount, "_transferTokens: transfer amount overflows");
        emit Transfer(src, dst, amount);

        _moveDelegates(delegates[src], delegates[dst], amount);
    }

    function _moveDelegates(address srcRep, address dstRep, uint96 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint96 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint96 srcRepNew = sub96(srcRepOld, amount, "_moveVotes: vote amount underflows");
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint96 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint96 dstRepNew = add96(dstRepOld, amount, "_moveVotes: vote amount overflows");
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint96 oldVotes, uint96 newVotes) internal {
      uint32 blockNumber = safe32(block.number, "_writeCheckpoint: block number exceeds 32 bits");

      if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
          checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
      } else {
          checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
          numCheckpoints[delegatee] = nCheckpoints + 1;
      }

      emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function safe96(uint n, string memory errorMessage) internal pure returns (uint96) {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function add96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        uint96 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function getChainId() internal pure returns (uint) {
        // uint256 chainId;
        // assembly { chainId := chainid() }
        // return chainId;
        return 1;   // mainnet id
    }
}

interface IDfTokenizedDeposits {
    function balanceOf(address account) external view returns(uint);
    function firstStageMaxLiquidity(address account) external view returns(uint);

    function withdrawProfit(address userAddress) external;
}

contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y, uint base) internal pure returns (uint z) {
        z = add(mul(x, y), base / 2) / base;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    /*function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }*/
}

contract DfxTokenStakable is
    Initializable,
    DSMath,
    DfxToken
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
    mapping (address => LockedBalance) public lockedBalances;   // locked balances (from dfx distribution stage 1)

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
     * @notice Initialize a new DFX token
     * @param account The initial account to grant all the tokens
     */
    function initialize(address account) public initializer {
        // Initialize Parent Contract
        DfxToken.initialize(account);
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

        if (stakedAmount        >= 250000) {   // 250k - +50 APY of locked DFX
            return 0.50 * 1e18;
        } else if (stakedAmount >= 50000) {    // 50k - +45 APY of locked DFX
            return 0.45 * 1e18;
        } else if (stakedAmount >= 25000) {    // 25k - +42.5 APY of locked DFX
            return 0.425 * 1e18;
        } else if (stakedAmount >= 10000) {    // 10k - +40 APY of locked DFX
            return 0.40 * 1e18;
        } else if (stakedAmount >= 5000) {     // 5k - +35 APY of locked DFX
            return 0.35 * 1e18;
        } else if (stakedAmount >= 2500) {     // 2.5k - +30 APY of locked DFX
            return 0.30 * 1e18;
        } else if (stakedAmount >= 500) {      // 0.5k - +25 APY of locked DFX
            return 0.25 * 1e18;
        } else if (stakedAmount >= 250) {      // 0.25k - +20 APY of locked DFX
            return 0.20 * 1e18;
        } else if (stakedAmount >= 50) {       // 50 - +1.5 APY of locked DFX
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

        if (ratio        >= 2.0 * 1e18) {   // x2.0 - +50 APY of locked DFX
            return 0.50 * 1e18;
        } else if (ratio >= 1.5 * 1e18) {   // x1.5 - +37.5 APY of locked DFX
            return 0.375 * 1e18;
        } else if (ratio >= 1.0 * 1e18) {   // x1.0 - +25 APY of locked DFX
            return 0.25 * 1e18;
        } else if (ratio >= 0.5 * 1e18) {   // x0.5 - +12.5 APY of locked DFX
            return 0.125 * 1e18;
        } else if (ratio >= 0.4 * 1e18) {   // x0.4 - +10 APY of locked DFX
            return 0.10 * 1e18;
        } else if (ratio >= 0.3 * 1e18) {   // x0.3 - +7.5 APY of locked DFX
            return 0.075 * 1e18;
        } else if (ratio >= 0.2 * 1e18) {   // x0.2 - +5 APY of locked DFX
            return 0.05 * 1e18;
        } else if (ratio >= 0.1 * 1e18) {   // x0.1 - +2.5 APY of locked DFX
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

        // Withdraw dai and dfx profit
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

        // Withdraw dai and dfx profit
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

    // call this function after 1 stage DFX distribution in Tokenized
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