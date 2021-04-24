pragma solidity ^0.5.17;
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

// **INTERFACES**

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IToken {
    function decimals() external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function approve(address spender, uint value) external;
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function deposit() external payable;
    function mint(address, uint256) external;
    function withdraw(uint amount) external;
    function totalSupply() view external returns (uint256);
    function burnFrom(address account, uint256 amount) external;
}

interface ICEther {
    function mint() external payable;
    function repayBorrow() external payable;
}

interface ICToken {
    function borrowIndex() view external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrow() external payable;

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower) external payable;

    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral)
        external
        returns (uint256);

    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function borrowRatePerBlock() external returns (uint256);

    function totalReserves() external returns (uint256);

    function reserveFactorMantissa() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function getCash() external returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function balanceOf(address owner) view external returns (uint256);

    function underlying() external returns (address);
}

contract IComptroller {
    mapping(address => uint) public compAccrued;

    function claimComp(address holder, address[] memory cTokens) public;

    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);

    function exitMarket(address cToken) external returns (uint256);

    function getAssetsIn(address account) external view returns (address[] memory);

    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);

    function markets(address cTokenAddress) external view returns (bool, uint);

    struct CompMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    function compSupplyState(address) view public returns(uint224, uint32);

    function compBorrowState(address) view public returns(uint224, uint32);

//    mapping(address => CompMarketState) public compBorrowState;

    mapping(address => mapping(address => uint)) public compSupplierIndex;

    mapping(address => mapping(address => uint)) public compBorrowerIndex;
}

// import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
// import "./SafeMath.sol";

// import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * IMPORTANT: It is unsafe to assume that an address for which this
     * function returns false is an externally-owned account (EOA) and not a
     * contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }

    /**
     * @dev Converts an `address` into `address payable`. Note that this is
     * simply a type cast: the actual underlying value is not changed.
     *
     * _Available since v2.4.0._
     */
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     *
     * _Available since v2.4.0._
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {

    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IToken token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IToken token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IToken token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IToken token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IToken token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IToken token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

library UniversalERC20 {

    using SafeMath for uint256;
    using SafeERC20 for IToken;

    IToken private constant ZERO_ADDRESS = IToken(0x0000000000000000000000000000000000000000);
    IToken private constant ETH_ADDRESS = IToken(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function universalTransfer(IToken token, address to, uint256 amount) internal {
        universalTransfer(token, to, amount, false);
    }

    function universalTransfer(IToken token, address to, uint256 amount, bool mayFail) internal returns(bool) {
        if (amount == 0) {
            return true;
        }

        if (token == ZERO_ADDRESS || token == ETH_ADDRESS) {
            if (mayFail) {
                return address(uint160(to)).send(amount);
            } else {
                address(uint160(to)).transfer(amount);
                return true;
            }
        } else {
            token.safeTransfer(to, amount);
            return true;
        }
    }

    function universalApprove(IToken token, address to, uint256 amount) internal {
        if (token != ZERO_ADDRESS && token != ETH_ADDRESS) {
            token.safeApprove(to, amount);
        }
    }

    function universalTransferFrom(IToken token, address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (token == ZERO_ADDRESS || token == ETH_ADDRESS) {
            require(from == msg.sender && msg.value >= amount, "msg.value is zero");
            if (to != address(this)) {
                address(uint160(to)).transfer(amount);
            }
            if (msg.value > amount) {
                msg.sender.transfer(uint256(msg.value).sub(amount));
            }
        } else {
            token.safeTransferFrom(from, to, amount);
        }
    }

    function universalBalanceOf(IToken token, address who) internal view returns (uint256) {
        if (token == ZERO_ADDRESS || token == ETH_ADDRESS) {
            return who.balance;
        } else {
            return token.balanceOf(who);
        }
    }
}

contract ConstantDfWallet {

    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address public constant COMP_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;

    address public constant DF_FINANCE_CONTROLLER = address(0xFff9D7b0B6312ead0a1A993BF32f373449006F2F); // TODO:
}

// DfWallet - logic of user's wallet for cTokens
contract DfWallet is ConstantDfWallet {
    using UniversalERC20 for IToken;

    // **MODIFIERS**

    modifier authCheck {
        require(msg.sender == DF_FINANCE_CONTROLLER, "Permission denied");
        _;
    }

    // **PUBLIC SET function**
    function claimComp(address[] memory cTokens) public authCheck {
        IComptroller(COMPTROLLER).claimComp(address(this), cTokens);
        IERC20(COMP_ADDRESS).transfer(msg.sender, IERC20(COMP_ADDRESS).balanceOf(address(this)));
    }

    // **PUBLIC PAYABLE functions**

    // Example: _collToken = Eth, _borrowToken = USDC
    function deposit(
        address _collToken, address _cCollToken, uint _collAmount, address _borrowToken, address _cBorrowToken, uint _borrowAmount
    ) public payable authCheck {
        // add _cCollToken to market
        enterMarketInternal(_cCollToken);

        // mint _cCollToken
        mintInternal(_collToken, _cCollToken, _collAmount);

        // borrow and withdraw _borrowToken
        if (_borrowToken != address(0)) {
            borrowInternal(_borrowToken, _cBorrowToken, _borrowAmount);
        }
    }

    function withdrawToken(address _tokenAddr, address to, uint256 amount) public authCheck {
        require(to != address(0));
        IToken(_tokenAddr).universalTransfer(to, amount);
    }

    // Example: _collToken = Eth, _borrowToken = USDC
    function withdraw(
        address _collToken, address _cCollToken, uint256 cAmountRedeem, address _borrowToken, address _cBorrowToken, uint256 amountRepay
    ) public payable authCheck returns (uint256) {
        // repayBorrow _cBorrowToken
        paybackInternal(_borrowToken, _cBorrowToken, amountRepay);

        // redeem _cCollToken
        return redeemInternal(_collToken, _cCollToken, cAmountRedeem);
    }

    function enterMarket(address _cTokenAddr) public authCheck {
        address[] memory markets = new address[](1);
        markets[0] = _cTokenAddr;

        IComptroller(COMPTROLLER).enterMarkets(markets);
    }

    function borrow(address _cTokenAddr, uint _amount) public authCheck {
        require(ICToken(_cTokenAddr).borrow(_amount) == 0);
    }

    function redeem(address _tokenAddr, address _cTokenAddr, uint256 amount) public authCheck {
        if (amount == uint256(-1)) amount = IERC20(_cTokenAddr).balanceOf(address(this));
        // converts all _cTokenAddr into the underlying asset (_tokenAddr)
        require(ICToken(_cTokenAddr).redeem(amount) == 0);
    }

    function payback(address _tokenAddr, address _cTokenAddr, uint256 amount) public payable authCheck {
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            if (amount == uint256(-1)) amount = ICToken(_cTokenAddr).borrowBalanceCurrent(address(this));

            IERC20(_tokenAddr).transferFrom(msg.sender, address(this), amount);
            require(ICToken(_cTokenAddr).repayBorrow(amount) == 0);
        } else {
            ICEther(_cTokenAddr).repayBorrow.value(msg.value)();
        }
    }

    function mint(address _tokenAddr, address _cTokenAddr, uint _amount) public payable authCheck {
        // approve _cTokenAddr to pull the _tokenAddr tokens
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            require(ICToken(_cTokenAddr).mint(_amount) == 0);
        } else {
            ICEther(_cTokenAddr).mint.value(msg.value)(); // reverts on fail
        }
    }

    // **INTERNAL functions**
    function approveCTokenInternal(address _tokenAddr, address _cTokenAddr) internal {
        if (_tokenAddr != ETH_ADDRESS) {
            if (IERC20(_tokenAddr).allowance(address(this), address(_cTokenAddr)) != uint256(-1)) {
                IERC20(_tokenAddr).approve(_cTokenAddr, uint(-1));
            }
        }
    }

    function enterMarketInternal(address _cTokenAddr) internal {
        address[] memory markets = new address[](1);
        markets[0] = _cTokenAddr;

        IComptroller(COMPTROLLER).enterMarkets(markets);
    }

    function mintInternal(address _tokenAddr, address _cTokenAddr, uint _amount) internal {
        // approve _cTokenAddr to pull the _tokenAddr tokens
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            require(ICToken(_cTokenAddr).mint(_amount) == 0);
        } else {
            ICEther(_cTokenAddr).mint.value(msg.value)(); // reverts on fail
        }
    }

    function borrowInternal(address _tokenAddr, address _cTokenAddr, uint _amount) internal {
        require(ICToken(_cTokenAddr).borrow(_amount) == 0);
    }

    function paybackInternal(address _tokenAddr, address _cTokenAddr, uint256 amount) internal {
        // approve _cTokenAddr to pull the _tokenAddr tokens
        approveCTokenInternal(_tokenAddr, _cTokenAddr);

        if (_tokenAddr != ETH_ADDRESS) {
            if (amount == uint256(-1)) amount = ICToken(_cTokenAddr).borrowBalanceCurrent(address(this));

            IERC20(_tokenAddr).transferFrom(msg.sender, address(this), amount);
            require(ICToken(_cTokenAddr).repayBorrow(amount) == 0);
        } else {
            ICEther(_cTokenAddr).repayBorrow.value(msg.value)();
            if (address(this).balance > 0) {
                transferEthInternal(msg.sender, address(this).balance);  // send back the extra eth
            }
        }
    }

    function redeemInternal(address _tokenAddr, address _cTokenAddr, uint256 amount) internal returns (uint256 tokensSent){
        // converts all _cTokenAddr into the underlying asset (_tokenAddr)
        if (amount == uint256(-1)) amount = IERC20(_cTokenAddr).balanceOf(address(this));
        require(ICToken(_cTokenAddr).redeem(amount) == 0);

        // withdraw funds to msg.sender
        if (_tokenAddr != ETH_ADDRESS) {
            tokensSent = IERC20(_tokenAddr).balanceOf(address(this));
            IToken(_tokenAddr).universalTransfer(msg.sender, tokensSent);
        } else {
            tokensSent = address(this).balance;
            transferEthInternal(msg.sender, tokensSent);
        }
    }

    // in case of changes in Compound protocol
    function externalCallEth(address payable[] memory  _to, bytes[] memory _data, uint256[] memory ethAmount) public authCheck payable {

        for(uint16 i = 0; i < _to.length; i++) {
            cast(_to[i], _data[i], ethAmount[i]);
        }

    }

    function cast(address payable _to, bytes memory _data, uint256 ethAmount) internal {
        bytes32 response;

        assembly {
            let succeeded := call(sub(gas, 5000), _to, ethAmount, add(_data, 0x20), mload(_data), 0, 32)
            response := mload(0)
            switch iszero(succeeded)
            case 1 {
                revert(0, 0)
            }
        }
    }

    function transferEthInternal(address _receiver, uint _amount) internal {
        address payable receiverPayable = address(uint160(_receiver));
        (bool result, ) = receiverPayable.call.value(_amount)("");
        require(result, "Transfer of ETH failed");
    }

    // **FALLBACK functions**
    function() external payable {}

}

// import "../openzeppelin/upgrades/contracts/Initializable.sol";

contract Ownable is Initializable {
    address payable public owner;
    address payable internal newOwnerCandidate;

    modifier onlyOwner {
        require(msg.sender == owner, "Permission denied");
        _;
    }

    // ** INITIALIZERS – Constructors for Upgradable contracts **

    function initialize() public initializer {
        owner = msg.sender;
    }

    function initialize(address payable newOwner) public initializer {
        owner = newOwner;
    }

    function changeOwner(address payable newOwner) public onlyOwner {
        newOwnerCandidate = newOwner;
    }

    function acceptOwner() public {
        require(msg.sender == newOwnerCandidate, "Permission denied");
        owner = newOwnerCandidate;
    }

    uint256[50] private ______gap;
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

contract ConstantAddresses {
    address public constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address public constant COMPOUND_ORACLE = 0x1D8aEdc9E924730DD3f9641CDb4D1B92B848b4bd;

//    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
//    address public constant CETH_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;

//    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//    address public constant CUSDC_ADDRESS = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

//    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CDAI_ADDRESS = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    address public constant COMP_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;

    address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
}

interface IDfFinanceDeposits {
    function createStrategyDeposit(uint256 amountDAI, uint256 flashLoanAmount, address dfWallet) external returns (address);
    function createStrategyDepositFlashloan(uint256 amountDAI, uint256 flashLoanAmount, address dfWallet) external returns (address);
    function createStrategyDepositMulti(uint256 amountDAI, uint256 flashLoanAmount, uint32 times) external;

    function closeDepositDAI(address dfWallet, uint256 minDAIForCompound, bytes calldata data) external;
    function closeDepositFlashloan(address dfWallet, uint256 minUsdForComp, bytes calldata data) external;

    function partiallyCloseDepositDAI(address dfWallet, address tokenReceiver, uint256 amountDAI) external;
    function partiallyCloseDepositDAIFlashloan(address dfWallet, address tokenReceiver, uint256 amountDAI) external;

    function claimComps(address dfWallet, uint256 minDAIForCompound, bytes calldata data) external returns(uint256);
    function isClosed(address addrWallet) view external returns(bool);
}

interface IPriceOracle {
    function price(string calldata symbol) external view returns (uint);
}

interface IDfxToken {
    function balanceOfStaked(address account) external view returns (uint);
    function totalSupply() external view returns (uint256);

    function __addLockedBalance(address user, uint lockedAmount) external;
    function __updateLockedBalance(address user) external;
}

interface IDiscount {
    function getDiscount(address dfxToken, address userAddress) view external returns(uint256);
}

contract DfTokenizedDeposit is
    Initializable,
    Ownable,
    DSMath,
    DfWallet
{
    using SafeMath for uint256;

    uint256 public constant START_BLOCK_1 = 0;     // TODO:
    uint256 public constant START_BLOCK_2 = 0;     // TODO:
    uint256 public constant END_BLOCK_1 = 0;       // TODO:
    uint256 public constant END_BLOCK_2 = 0;       // TODO:

    uint256 public constant DFX_PER_BLOCK_1 = 0;    // TODO:
    uint256 public constant DFX_PER_BLOCK_2 = 0;    // TODO:

    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CDAI_ADDRESS = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    address public constant COMP_ADDRESS = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    // IDfFinanceDeposits public constant dfFinanceDeposits = IDfFinanceDeposits(0xCa0648C5b4Cea7D185E09FCc932F5B0179c95F17); // Kovan
    IDfFinanceDeposits public constant dfFinanceDeposits = IDfFinanceDeposits(0xFff9D7b0B6312ead0a1A993BF32f373449006F2F); // Mainnet

    address public liquidityProviderAddress;

    uint256 public accDaiPerShare;

    uint256 public accDfxPerShare1;     // DFX distribution stage 1
    uint256 public accDfxPerShare2;     // DFX distribution stage 2

    uint256 public lastDfxRewardBlock1;  // Last block number that DFXs distribution occurs – stage 1.
    uint256 public lastDfxRewardBlock2;  // Last block number that DFXs distribution occurs – stage 2.

    struct UserData {
        uint256 rewardDebt;
        uint256 balance;
        uint128 rewardDfxDebt1;
        uint128 rewardDfxDebt2;
    }
    mapping(address => UserData) public userInfo;
    uint256 public totalSupply;

    mapping(address => uint) public firstStageMaxLiquidity;

    uint256 public lastDatetimeClaimProfit;
    uint256 public totalProfit;
    IPriceOracle public constant compOracle = IPriceOracle(0x9B8Eb8b3d6e2e0Db36F41455185FEF7049a35CaE);

    uint256   public multiplicator;
    address   public devFund;
    IDfxToken public dfxToken;
    IDiscount public dfDiscount;
    uint256   public devFundPercent; // from 0 to 100
    uint256   public profitInterval;
    uint256   public currentDevProfit;
    uint256   public totalDevProfit;
    uint256   public enterFee;

    bool      public isStopped;
    uint256   public emergencyWithdrawnBalance;
    address   public controller;

    event DevFundPercentChanges(uint256 _oldValue, uint256 _newValue);
    event DevFundAddressChanges(address indexed _oldAddress, address indexed _newAddress);
    event MultiplicatorChanged(uint256 _oldValue, uint256 _newValue);
    event Profit(address indexed userAddress, uint256 profit);
    event Deposit(address indexed userAddress, uint256 amount);
    event Withdraw(address indexed userAddress, uint256 amount);
    event DfxProfit(address indexed user, uint256 dfxProfitStage1, uint256 dfxProfitStage2);
    event Discount(address indexed user, uint256 profit, uint256 extraProfit);
    event CompSwap(uint256 timestamp, uint256 compPrice, uint256 compAmount, uint256 totalSupply);
    event EnterFeeChanged(uint256 newFeeAmount);
    event DiscountModelChanged(address _newDiscountModel);
    event ControllerChanged(address _newController);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Reinvest(address indexed user, uint256 amount);

    function initialize() public initializer {
        address payable curOwner = 0xdAE0aca4B9B38199408ffaB32562Bf7B3B0495fE;
        Ownable.initialize(curOwner);  // Initialize Parent Contract

        IToken(DAI_ADDRESS).approve(address(dfFinanceDeposits), uint256(-1));
        multiplicator = 290;
        devFund = curOwner;
        profitInterval = 12 hours;
        enterFee = 25 * 10000; // 0.25% = 0.0025 = 25 / 10000
        // dfxToken = 0xdAE0aca4B9B38199408ffaB32562Bf7B3B0495fE;
    }

    // token-like functions (to view balance via MetaMask or other wallet)
    function balanceOf(address who) public view returns (uint256) {
        return userInfo[who].balance;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function name() public pure returns (string memory) {
        return "DeFireX DAI";
    }

    function symbol() public pure returns (string memory) {
        return "DDAI";
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        UserData storage user1 = userInfo[from];
        require(user1.balance >= amount);
        UserData storage user2 = userInfo[to];
        updateDfxPool();
        distRewards(from);
        distRewards(to);

        user1.balance = sub(user1.balance, amount);
        user2.balance = add(user2.balance, amount);
    }
    // token-like functions (ends)

    // 0.25% = 25 * 10000
    function changeEnterFee(uint256 _newValue) public {
        require(msg.sender == owner);
        require(_newValue <= 50 * 10000); // 0.5% - max
        enterFee = _newValue;
        emit EnterFeeChanged(_newValue);
    }

    function changeController(address _newAddress) public {
        require(msg.sender == owner);
        controller = _newAddress;
        emit ControllerChanged(_newAddress);
    }

    function setDfxToken(address _newTokenAddress) public {
        require(msg.sender == owner);
//        require(dfxToken == IDfxToken(0)); // TODO: change in production
        dfxToken = IDfxToken(_newTokenAddress);
    }

    function setDevFundPercent(uint256 _newValue) public {
        require(msg.sender == owner);
        require(_newValue >= 0 && _newValue <= 50);
        emit DevFundPercentChanges(devFundPercent, _newValue);
        devFundPercent = _newValue;
    }

    function setDiscountModel(address _newAddress) public {
        require(msg.sender == owner);
        dfDiscount = IDiscount(_newAddress);
        emit DiscountModelChanged(_newAddress);
    }

    function withdrawDev(uint256 _amount) public {
        require(msg.sender == devFund);
        uint256 _currentDevProfit = currentDevProfit;
        if (_currentDevProfit >= _amount) {
            currentDevProfit = sub(_currentDevProfit, _amount);
            totalDevProfit   = add(totalDevProfit, _amount);
            IToken(DAI_ADDRESS).transfer(devFund, _amount);
        }
    }

    function setLiquidityProviderAddress(address newAddress) public {
        require(msg.sender == owner);
        liquidityProviderAddress = newAddress;
    }

    function setProfitInterval(uint256 _newValue) public {
        require(msg.sender == owner);
        profitInterval = _newValue;
    }

    function setDevFund(address newAddress) public {
        require(msg.sender == owner);
        emit DevFundAddressChanges(devFund, newAddress);
        devFund = newAddress;
    }

    function setMultiplicator(uint256 newValue) public {
        require(msg.sender == owner);
        require(newValue <= 290);
        require(newValue >= 100);
        emit MultiplicatorChanged(multiplicator, newValue);
        multiplicator = newValue;
    }

    function processFeesAndDiscounts(uint256 pendingDai) internal view returns(uint256 pendingDaiNew, uint256 extraProfit, uint256 devProfit) {
        IDiscount _dfDiscount = dfDiscount;
        uint256 discount = (_dfDiscount == IDiscount(0)) ? 0 : _dfDiscount.getDiscount(address(dfxToken), msg.sender);

        devProfit = pendingDai * devFundPercent / 100;
        pendingDai = sub(pendingDai, devProfit); // pendingDai minus dev commission

        if (discount > 0) {
            extraProfit = devProfit * discount / 100;
            devProfit = sub(devProfit, extraProfit);

            pendingDai = add(pendingDai, extraProfit);
        }

        pendingDaiNew = pendingDai;
    }

    function getUserInfoForHumans(address userAddress) view public returns (uint256 userDepositDai, uint256 pendingProfitDai, uint256 discountDai, uint256 dfxTokens) {
        (userDepositDai, pendingProfitDai, discountDai, dfxTokens) = getUserInfo(userAddress);
        userDepositDai = userDepositDai / 1e18;
        pendingProfitDai = pendingProfitDai / 1e18;
        discountDai = discountDai / 1e18;
        dfxTokens = dfxTokens / 1e18;
    }

    function getUserInfo(address userAddress) view public returns (uint256 userDepositDai, uint256 pendingProfitDai, uint256 discountDai, uint256 dfxTokens) {
        UserData memory user = userInfo[userAddress];

        userDepositDai = user.balance;
        if (userDepositDai > 0) {
            pendingProfitDai = sub(wmul(userDepositDai, accDaiPerShare), user.rewardDebt);
            if (pendingProfitDai > 0) {
                uint256 pendingProfitDaiNew;
                (pendingProfitDaiNew,,) = processFeesAndDiscounts(pendingProfitDai);
                if (pendingProfitDaiNew > pendingProfitDai) discountDai = pendingProfitDaiNew - pendingProfitDai;
                pendingProfitDai = pendingProfitDaiNew;
            }
        }

        dfxTokens = dfxToken.balanceOfStaked(userAddress);
    }

    // Return reward in DFX over the given _from to _to block for first stage.
    function getDfxRewardFirstStage(uint256 _from, uint256 _to) public pure returns (uint256) {
        uint from = max(_from, START_BLOCK_1);
        uint to = min(_to, END_BLOCK_1);
        return (to > from) ? to.sub(from).mul(DFX_PER_BLOCK_1) : 0;
    }

    // Return reward in DFX over the given _from to _to block for second stage.
    function getDfxRewardSecondStage(uint256 _from, uint256 _to) public pure returns (uint256) {
        uint from = max(_from, START_BLOCK_2);
        uint to = min(_to, END_BLOCK_2);
        return (to > from) ? to.sub(from).mul(DFX_PER_BLOCK_2) : 0;
    }

    // View function to see pending DFX on frontend.
    function pendingDfx(address _user) public view returns(
        uint256 pendingDfx1,
        uint256 pendingDfx2
    ) {
        UserData storage user = userInfo[_user];

        uint _accDfxPerShare1 = accDfxPerShare1;
        uint _accDfxPerShare2 = accDfxPerShare2;
        uint _lastDfxRewardBlock1 = lastDfxRewardBlock1;
        uint _lastDfxRewardBlock2 = lastDfxRewardBlock2;

        uint _totalSupply = totalSupply;
        uint _blockNumber = _getBlockNumber();

        if (_blockNumber > _lastDfxRewardBlock1 && _totalSupply != 0) {
            uint dfxReward = getDfxRewardFirstStage(_lastDfxRewardBlock1, _blockNumber);
            _accDfxPerShare1 = _accDfxPerShare1.add(dfxReward.mul(1e18).div(_totalSupply));
        }

        if (_blockNumber > _lastDfxRewardBlock2 && _totalSupply != 0) {
            uint dfxReward = getDfxRewardSecondStage(_lastDfxRewardBlock2, _blockNumber);
            _accDfxPerShare2 = _accDfxPerShare2.add(dfxReward.mul(1e18).div(_totalSupply));
        }

        pendingDfx1 = user.balance.mul(_accDfxPerShare1).div(1e18).sub(user.rewardDfxDebt1);
        pendingDfx2 = user.balance.mul(_accDfxPerShare2).div(1e18).sub(user.rewardDfxDebt2);
    }

    // Update reward DFX variables of the DFX pool to be up-to-date.
    function updateDfxPool() public {
        uint curBlock = _getBlockNumber();

        if (curBlock <= lastDfxRewardBlock1 && curBlock <= lastDfxRewardBlock2) {
            return;
        }

        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            lastDfxRewardBlock1 = lastDfxRewardBlock2 = curBlock;
            return;
        }

        if (curBlock >= START_BLOCK_1) {
            uint dfxReward = getDfxRewardFirstStage(lastDfxRewardBlock1, curBlock);

            accDfxPerShare1 = accDfxPerShare1.add(dfxReward.mul(1e18).div(_totalSupply));
            lastDfxRewardBlock1 = curBlock;
        }

        if (curBlock >= START_BLOCK_2) {
            uint dfxReward = getDfxRewardSecondStage(lastDfxRewardBlock2, curBlock);

            accDfxPerShare2 = accDfxPerShare2.add(dfxReward.mul(1e18).div(_totalSupply));
            lastDfxRewardBlock2 = curBlock;
        }
    }

    function reinvest() public returns (uint256) {
        address account = msg.sender;

        // update locked balance of DFX
        dfxToken.__updateLockedBalance(account);

        return _deposit(account, 0, true);
    }

    function deposit(uint256 amount) public returns (uint256){
        address account = msg.sender;

        // update locked balance of DFX
        dfxToken.__updateLockedBalance(account);

        return _deposit(account, amount, false);
    }

    function withdraw(uint256 amount) public {
        address account = msg.sender;

        // update locked balance of DFX
        dfxToken.__updateLockedBalance(account);

        _withdraw(account, amount);
    }

    function withdrawProfit(address userAddress) public {
        _deposit(userAddress, 0, false);
    }

    function sync() public {
        require(msg.sender == controller);
        uint256 amount;
        if (isStopped) {
            amount = emergencyWithdrawnBalance;
            emergencyWithdrawnBalance = 0;
            isStopped = false;
        } else {
            amount = sub(ICToken(CDAI_ADDRESS).borrowBalanceCurrent(address(this)), 2);
            dfFinanceDeposits.partiallyCloseDepositDAIFlashloan(address(this), address(this), amount);
        }

        dfFinanceDeposits.createStrategyDepositFlashloan(amount, amount * multiplicator / 100, address(this));
    }

    function emergencyStop() public {
        require(isStopped == false);
        require(msg.sender == controller);
        uint256 amount = sub(ICToken(CDAI_ADDRESS).borrowBalanceCurrent(address(this)), 2);
        uint256 savedBalance = IToken(DAI_ADDRESS).balanceOf(address(this));
        dfFinanceDeposits.partiallyCloseDepositDAIFlashloan(address(this), address(this), amount);
        emergencyWithdrawnBalance = sub(IToken(DAI_ADDRESS).balanceOf(address(this)), savedBalance);
        isStopped = true;
    }

    function claimAndExchange(uint256 _comp_dai_Price) public {
        require(msg.sender == tx.origin);
        claimComps();
        exchangeComps(_comp_dai_Price);
    }

    function claimComps() internal {
        dfFinanceDeposits.claimComps(address(this), 0, bytes(""));
    }

    function getCompPriceInDAI() view public returns(uint256) {
        //  price not less that price from oracle with 0.1% slippage
        return compOracle.price("COMP") * 1e18 / compOracle.price("DAI") * 999 / 1000;
        //  return 185915000 * 1e18 / 1005687 * 999 / 1000;
    }

    function exchangeComps(uint256 _comp_dai_Price) internal {

        require(block.timestamp - lastDatetimeClaimProfit > profitInterval);

        require( _comp_dai_Price >= getCompPriceInDAI() );

        uint256 compAmount = IToken(COMP_ADDRESS).balanceOf(address(this));

        uint256 totalDai = wmul(_comp_dai_Price, compAmount);
        IToken(DAI_ADDRESS).transferFrom(msg.sender, address(this), totalDai);
        IToken(COMP_ADDRESS).transfer(msg.sender, compAmount);

        lastDatetimeClaimProfit = block.timestamp;
        accDaiPerShare = add(accDaiPerShare, wdiv(totalDai, totalSupply));
        totalProfit = add(totalProfit, totalDai);

        emit CompSwap(block.timestamp, _comp_dai_Price, compAmount, totalSupply);
    }

    // ** INTERNAL VIEW functions **

    function _getBlockNumber() internal view returns(uint) {
        return block.number;
    }

    // ** INTERNAL functions **

    // function used only to send pending payment for liquidity provider without any discounts\fees
    function calcAndSendPendingPaymentForLP(address userAddress) internal {
        UserData storage user = userInfo[userAddress];
        uint256 _balance = user.balance;
        if (_balance > 0) {
            uint256 _accDaiPerShare = accDaiPerShare;
            uint256 pendingDai = sub(wmul(_balance, _accDaiPerShare), user.rewardDebt);
            if (pendingDai > 0) {
                IToken(DAI_ADDRESS).transfer(userAddress, pendingDai);
                user.rewardDebt = wmul(_balance, _accDaiPerShare);
            }
        }
    }

    function _distributeDfx(address userAddress) internal {
        (uint pendingDfx1, uint pendingDfx2) = pendingDfx(userAddress);
        uint dfxToWithdraw = pendingDfx1.add(pendingDfx2);

        if (dfxToWithdraw > 0) {
            IToken(address(dfxToken)).transfer(userAddress, dfxToWithdraw);
            emit DfxProfit(userAddress, pendingDfx1, pendingDfx2);
        }

        // lock pendingDfx1 balance
        if (pendingDfx1 > 0) {
            dfxToken.__addLockedBalance(userAddress, pendingDfx1);
        }
    }

    function _deposit(address userAddress, uint256 amount, bool isReinvest) internal returns (uint256 pendingDai) {
        // Update reward DFX pool
        updateDfxPool();

        UserData storage user = userInfo[userAddress];

        uint256 _userBalance = user.balance;
        if (_userBalance > 0) {
            pendingDai = sub(wmul(_userBalance, accDaiPerShare), user.rewardDebt);
            if (pendingDai > 0) {
                uint256 devProfit;
                uint256 extraProfit;
                (pendingDai, devProfit, extraProfit) = processFeesAndDiscounts(pendingDai);
                if (devProfit > 0)  currentDevProfit += devProfit;
                if (extraProfit > 0) emit Discount(userAddress, pendingDai, extraProfit);

                if (isReinvest) {
                    user.balance = add(_userBalance, pendingDai);
                    emit Reinvest(userAddress, pendingDai);
                } else {
                    emit Profit(userAddress, pendingDai);
                    IToken(DAI_ADDRESS).transfer(userAddress, pendingDai);
                }
            }

            _distributeDfx(userAddress);
        }

        if (amount > 0) {
            address _liquidityProviderAddress = liquidityProviderAddress;
            uint256 _liquidityProviderBalance = userInfo[_liquidityProviderAddress].balance;
            if (_liquidityProviderBalance >= amount && _liquidityProviderAddress != userAddress) {
                calcAndSendPendingPaymentForLP(_liquidityProviderAddress);
                IToken(DAI_ADDRESS).transferFrom(userAddress, _liquidityProviderAddress, amount);
                userInfo[_liquidityProviderAddress].balance = sub(_liquidityProviderBalance, amount);
            } else {
                IToken(DAI_ADDRESS).transferFrom(userAddress, address(this), amount);
                dfFinanceDeposits.createStrategyDepositFlashloan(amount, amount * multiplicator / 100, address(this));
                totalSupply = add(totalSupply, amount);
            }

            user.balance = add(_userBalance, amount);
            emit Deposit(userAddress, amount);
        }

        _userBalance = user.balance;
        user.rewardDebt = wmul(_userBalance, accDaiPerShare);
        user.rewardDfxDebt1 = uint128(_userBalance.mul(accDfxPerShare1).div(1e18));
        user.rewardDfxDebt2 = uint128(_userBalance.mul(accDfxPerShare2).div(1e18));

        // update max liquidity of first stage
        if (_getBlockNumber() <= END_BLOCK_1 && _userBalance > firstStageMaxLiquidity[userAddress]) {
            firstStageMaxLiquidity[userAddress] = _userBalance;
        }
    }

    function distRewards(address userAddress) internal {
        UserData storage user = userInfo[userAddress];
        uint256 _userBalance = user.balance;
        if (_userBalance > 0) {
            uint256 pendingDai = sub(wmul(_userBalance, accDaiPerShare), user.rewardDebt);
            if (pendingDai > 0) {
                emit Profit(userAddress, pendingDai);

                uint256 devProfit;
                uint256 extraProfit;
                (pendingDai, devProfit, extraProfit) = processFeesAndDiscounts(pendingDai);
                if (devProfit > 0)  currentDevProfit += devProfit;
                if (extraProfit > 0) emit Discount(userAddress, pendingDai - extraProfit, extraProfit);

                IToken(DAI_ADDRESS).transfer(userAddress, pendingDai);
            }
            _distributeDfx(userAddress);
        }
        user.rewardDebt = wmul(_userBalance, accDaiPerShare);
        user.rewardDfxDebt1 = uint128(_userBalance.mul(accDfxPerShare1).div(1e18));
        user.rewardDfxDebt2 = uint128(_userBalance.mul(accDfxPerShare2).div(1e18));
    }

    function _withdraw(address userAddress, uint256 amount) internal {
        // Update reward DFX pool
        updateDfxPool();

        UserData storage user = userInfo[userAddress];
        uint256 _userBalance = user.balance;

        if (amount == uint256(-1)) {
            amount = _userBalance; // all user balance
        } else {
            require(_userBalance >= amount);
        }

        if (_userBalance > 0) {
            uint256 pendingDai = sub(wmul(_userBalance, accDaiPerShare), user.rewardDebt);
            if (pendingDai > 0) {
                emit Profit(userAddress, pendingDai);

                uint256 devProfit;
                uint256 extraProfit;
                (pendingDai, devProfit, extraProfit) = processFeesAndDiscounts(pendingDai);
                if (devProfit > 0)  currentDevProfit += devProfit;
                if (extraProfit > 0) emit Discount(userAddress, pendingDai - extraProfit, extraProfit);

                IToken(DAI_ADDRESS).transfer(userAddress, pendingDai);
            }
            _distributeDfx(userAddress);
        }

        if (amount > 0) {
            address _liquidityProviderAddress = liquidityProviderAddress;
            uint256 _liquidityProviderBalanceDai = IToken(DAI_ADDRESS).balanceOf(_liquidityProviderAddress);
            if (_liquidityProviderBalanceDai >= amount && _liquidityProviderAddress != userAddress) {
                calcAndSendPendingPaymentForLP(_liquidityProviderAddress);
                IToken(DAI_ADDRESS).transferFrom(_liquidityProviderAddress, userAddress, amount);
                userInfo[_liquidityProviderAddress].balance = add(userInfo[_liquidityProviderAddress].balance, amount);
            } else {
                if (isStopped) {
                    emergencyWithdrawnBalance = sub(emergencyWithdrawnBalance, amount);
                    IToken(DAI_ADDRESS).transfer(msg.sender, amount);
                } else {
                    dfFinanceDeposits.partiallyCloseDepositDAIFlashloan(address(this), msg.sender, amount);
                }
                totalSupply = sub(totalSupply, amount);
            }

            user.balance = sub(_userBalance, amount);
            emit Withdraw(userAddress, amount);
        }

        _userBalance = user.balance;
        user.rewardDebt = wmul(_userBalance, accDaiPerShare);
        user.rewardDfxDebt1 = uint128(_userBalance.mul(accDfxPerShare1).div(1e18));
        user.rewardDfxDebt2 = uint128(_userBalance.mul(accDfxPerShare2).div(1e18));
    }
}