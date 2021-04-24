pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./DfWalletDeposits.sol";
import "../access/Ownable.sol";

import "../utils/DSMath.sol";
import "../utils/SafeMath.sol";

import "../constants/ConstantAddressesMainnet.sol";

import "../interfaces/IDfFinanceDeposits.sol";
import "../interfaces/IToken.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IDfxToken.sol";
import "../interfaces/IDiscount.sol";


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