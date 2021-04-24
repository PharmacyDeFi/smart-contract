pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "../access/FundsManager.sol";
import "../access/Adminable.sol";

import "../constants/ConstantAddressesMainnet.sol";

import "../utils/DSMath.sol";
import "../utils/SafeMath.sol";

import "../flashloan/base/FlashLoanReceiverBase.sol";
import "../dydxFlashloan/FlashloanDyDx.sol";

// **INTERFACES**
import "../compound/interfaces/ICompoundOracle.sol";
import "../compound/interfaces/IComptroller.sol";
import "../compound/interfaces/ICToken.sol";
import "../flashloan/interfaces/ILendingPool.sol";
import "../interfaces/IDfWallet.sol";
import "../interfaces/IDfWalletFactory.sol";
import "../interfaces/IToken.sol";
import "../interfaces/IOneInchExchange.sol";
import "../interfaces/IComptrollerLensInterface.sol";


contract DfFinanceDeposits is
    Initializable,
    DSMath,
    ConstantAddresses,
    FundsManager,
    Adminable,
    FlashLoanReceiverBase,
    FlashloanDyDx
{
    using UniversalERC20 for IToken;
    using SafeMath for uint256;


    // ** STRUCTS **

    struct FeeScheme {
        address[] partners;
        uint32[] percents;
        uint32 fee;
        bool isEnabled;
    }

    struct UserData {
        address owner;
        uint256 deposit; //
        // uint256 targetAmount; // 6 decimals
        uint64 compClaimed;
        uint64 compClaimedinUSD; // 6 decimals
        uint64 activeFeeScheme; // 0 - fee scheme is disabled
        uint64 gap2;
    }

    struct FlashloanDyDxData {
        address dfWallet;
        uint256 deposit;
        uint256 amountFlashLoan;
    }


    // ** ENUMS **

    enum OP {
        UNKNOWN,
        OPEN,
        CLOSE,
        PARTIALLYCLOSE
    }

    enum FlashloanProvider {
        DYDX,
        AAVE
    }


    // ** PUBLIC STATES **

    IDfWalletFactory public dfWalletFactory;

    uint256 public fee;

    mapping(address => UserData) public wallets;


    // ** PRIVATE STATES **

    // partner => token => balance
    mapping(address => mapping(address => uint256)) private partnerBalances;

    FeeScheme[] private feeSchemes;

    OP private state;


    // ** NEW STATES **

    FlashloanProvider public flashloanProvider;     // Flashloan Aave or dYdX


    // ** EVENTS **

    event DfOpenDeposit(address indexed dfWallet, uint256 amount);
    event DfAddDeposit(address indexed dfWallet, uint256 amount);
    event DfCloseDeposit(address indexed dfWallet, uint256 amount, address token);
    event DfPartiallyCloseDeposit(
        address indexed dfWallet, address indexed tokenReceiver, uint256 amountDAI, uint256 tokensSent,  uint256 deposit
    );


    // ** MODIFIERS **

    modifier balanceCheck {
        uint256 startBalance = IToken(DAI_ADDRESS).balanceOf(address(this));
        _;
        require(IToken(DAI_ADDRESS).balanceOf(address(this)) >= startBalance);
    }


    // ** INITIALIZER – Constructor for Upgradable contracts **

    function initialize() public initializer {
        Adminable.initialize();  // Initialize Parent Contract
        // FundsManager.initialize();  // Init in Adminable

        // dfWalletFactory = IDfWalletFactory(0x0b7B605F6e5715933EF83505F1db9F2Df3C52FF4);
    }


    // ** PUBLIC VIEW functions **

    function getPartnerBalances(address _userAddress, address _token) public view returns(uint256){
        return partnerBalances[_userAddress][_token];
    }

    function getFeeScheme(uint256 _index) public view returns (uint32 _fee, address[] memory _partners, uint32[] memory _percents) {
        _fee = feeSchemes[_index].fee;
        _partners = feeSchemes[_index].partners;
        _percents = feeSchemes[_index].percents;
    }

    function isClosed(address addrWallet) public view returns(bool) {
        return wallets[addrWallet].deposit == 0 && wallets[addrWallet].owner != address(0x0);
    }

    // function getMaxFeeSchemes() public view returns (uint256) {
    //     return feeSchemes.length;
    // }


    // ** ONLY_OWNER functions **

    function setFlashloanProvider(FlashloanProvider _flashloanProvider) public onlyOwner {
        flashloanProvider = _flashloanProvider;
    }

    function setDfWalletFactory(address _dfWalletFactory) public onlyOwner {
        require(_dfWalletFactory != address(0));
        dfWalletFactory = IDfWalletFactory(_dfWalletFactory);
    }

    function changeFee(uint256 _fee) public onlyOwner {
        require(_fee < 100);
        fee = _fee;
    }

    function addNewFeeScheme(uint32 _fee, address[] memory _partners, uint32[] memory _percents, bool _isEnabled) public onlyOwner {
        // FeeScheme storage newScheme;
        // newScheme.fee = _fee;
        // newScheme.partners = _partners;
        // newScheme.percents = _percents;
        // newScheme.isEnabled = _isEnabled;
        feeSchemes.push(FeeScheme(_partners, _percents, _fee, _isEnabled));
    }
    function enabledFeeScheme(uint256 _index, bool _isEnabled) public onlyOwner {
        require(_index < feeSchemes.length);
        feeSchemes[_index].isEnabled = _isEnabled;
    }


    // ** PUBLIC functions **

    function getCompBalanceMetadataExt(address account) external returns (uint256 balance, uint256 allocated) {
        IComptrollerLensInterface comptroller = IComptrollerLensInterface(COMPTROLLER);
        IToken comp = IToken(COMP_ADDRESS);
        balance = comp.balanceOf(account);
        comptroller.claimComp(account);
        uint256 newBalance = comp.balanceOf(account);
        uint256 accrued = comptroller.compAccrued(account);
        uint256 total = add(accrued, newBalance);
        allocated = sub(total, balance);
    }


    // CREATE functions

    function createStrategyDeposit(uint256 amountDAI, uint256 flashLoanAmount, address dfWallet) public balanceCheck returns (address) {
        if (dfWallet == address(0x0)) {
            dfWallet = dfWalletFactory.createDfWallet();
            IToken(DAI_ADDRESS).approve(dfWallet, uint256(-1));
            wallets[dfWallet] = UserData(msg.sender, amountDAI, 0, 0, 0, 0);
            emit DfOpenDeposit(dfWallet, amountDAI);
        } else {
            require(wallets[dfWallet].owner == msg.sender);
            wallets[dfWallet].deposit = add(wallets[dfWallet].deposit, amountDAI);
            emit DfAddDeposit(dfWallet, amountDAI);
        }

        // Transfer tokens to wallet
        IToken(DAI_ADDRESS).universalTransferFrom(msg.sender, address(this), amountDAI);

        uint256 totalFunds = flashLoanAmount + amountDAI;

        IToken(DAI_ADDRESS).transfer(dfWallet, totalFunds);

        IDfWallet(dfWallet).deposit(DAI_ADDRESS, CDAI_ADDRESS, totalFunds, DAI_ADDRESS, CDAI_ADDRESS, flashLoanAmount);

        IDfWallet(dfWallet).withdrawToken(DAI_ADDRESS, address(this), flashLoanAmount);

        return dfWallet;
    }

    function createStrategyDepositFlashloan(uint256 amountDAI, uint256 flashLoanAmount, address dfWallet) public returns (address) {

        if (dfWallet == address(0x0)) {
            dfWallet = dfWalletFactory.createDfWallet();
            IToken(DAI_ADDRESS).approve(dfWallet, uint256(-1));
            wallets[dfWallet] = UserData(msg.sender, amountDAI, 0, 0, 0, 0);
            emit DfOpenDeposit(dfWallet, amountDAI);
        } else {
            require(wallets[dfWallet].owner == msg.sender);
            wallets[dfWallet].deposit = add(wallets[dfWallet].deposit, amountDAI);
            emit DfAddDeposit(dfWallet, amountDAI);
        }
        // Transfer tokens to wallet
        IToken(DAI_ADDRESS).universalTransferFrom(msg.sender, dfWallet, amountDAI);

        // FLASHLOAN LOGIC
        state = OP.OPEN;

        if (flashloanProvider == FlashloanProvider.AAVE) {
            ILendingPool lendingPool = ILendingPool(ILendingPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getLendingPool());
            lendingPool.flashLoan(address(this), DAI_ADDRESS, flashLoanAmount, abi.encodePacked(dfWallet, amountDAI));
        } else {
            _initFlashloanDyDx(
                DAI_ADDRESS,
                flashLoanAmount,
                // Encode FlashloanDyDxData for callFunction
                abi.encode(FlashloanDyDxData({dfWallet: dfWallet, deposit: amountDAI, amountFlashLoan: flashLoanAmount}))
            );
        }

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC

        return dfWallet;
    }

    function createStrategyDepositMulti(uint256 amountDAI, uint256 flashLoanAmount, uint32 times) balanceCheck public {
        address dfWallet = createStrategyDeposit(amountDAI, flashLoanAmount, address(0x0));
        for(uint32 t = 0; t < times;t++) {
            createStrategyDeposit(amountDAI, flashLoanAmount, dfWallet);
        }
    }


    // CLAIM and WITHDRAW functions

    function claimComps(address dfWallet, uint256 minUsdForComp, bytes memory data) public returns(uint256) {
        require(wallets[dfWallet].owner == msg.sender);

        uint256 compTokenBalance = IToken(COMP_ADDRESS).balanceOf(address(this));
        address[] memory cTokens = new address[](1);
        cTokens[0] = CDAI_ADDRESS;
        IDfWallet(dfWallet).claimComp(cTokens);

        compTokenBalance = sub(IToken(COMP_ADDRESS).balanceOf(address(this)), compTokenBalance);

        if (minUsdForComp > 0) {
            uint256 usdtAmount = _exchange(IToken(COMP_ADDRESS), compTokenBalance, IToken(USDT_ADDRESS), minUsdForComp, data);
            usdtAmount = _distFees(USDT_ADDRESS, usdtAmount, dfWallet);

            IToken(USDT_ADDRESS).universalTransfer(msg.sender, usdtAmount);
            wallets[dfWallet].compClaimedinUSD += uint64(usdtAmount);
            return usdtAmount;
        } else {
            compTokenBalance = _distFees(COMP_ADDRESS, compTokenBalance, dfWallet);
            IToken(COMP_ADDRESS).transfer(msg.sender, compTokenBalance);
            wallets[dfWallet].compClaimed += uint64(compTokenBalance / 1e12); // 6 decemals
            return compTokenBalance;
        }
    }

    function withdrawPartnerReward(address _token) public {
        require(msg.sender == tx.origin);
        uint256 reward = partnerBalances[msg.sender][_token];
        require(reward > 0);
        partnerBalances[msg.sender][_token] = 0;
        IToken(_token).universalTransfer(msg.sender, reward);
    }


    // CLOSE functions

    function closeDepositDAI(address dfWallet, uint256 minUsdForComp, bytes memory data) public balanceCheck {
        require(wallets[dfWallet].owner == msg.sender);
        require(wallets[dfWallet].deposit > 0);

        uint256 startBalance = IToken(DAI_ADDRESS).balanceOf(address(this));
        // uint256 totalBorrowed = ICToken(CDAI_ADDRESS).borrowBalanceCurrent(dfWallet);
        // require(startBalance >= totalBorrowed);

        if (IToken(DAI_ADDRESS).allowance(address(this), dfWallet) != uint256(-1)) {
            IToken(DAI_ADDRESS).approve(dfWallet, uint256(-1));
        }

        IDfWallet(dfWallet).withdraw(DAI_ADDRESS, CDAI_ADDRESS, uint(-1), DAI_ADDRESS, CDAI_ADDRESS, uint(-1));

        // withdraw body
        uint256 userBalance = sub(IToken(DAI_ADDRESS).balanceOf(address(this)), startBalance);
        _withdrawBodyAndChangeWalletInfo(dfWallet, userBalance);

        // withdraw comp
        if (minUsdForComp > 0) {
            IDfWallet(dfWallet).withdrawToken(COMP_ADDRESS, address(this), IToken(COMP_ADDRESS).balanceOf(dfWallet));
            uint256 amountUsdt = _exchange(IToken(COMP_ADDRESS), IToken(COMP_ADDRESS).balanceOf(dfWallet), IToken(USDT_ADDRESS), minUsdForComp, data);

            amountUsdt = _distFees(USDT_ADDRESS, amountUsdt, dfWallet);

            wallets[dfWallet].compClaimedinUSD += uint64(amountUsdt);
            IToken(USDT_ADDRESS).universalTransfer(msg.sender, amountUsdt);
            emit DfCloseDeposit(dfWallet, amountUsdt, USDT_ADDRESS);
        } else {
            uint256 totalComp = IToken(COMP_ADDRESS).balanceOf(dfWallet);
            IDfWallet(dfWallet).withdrawToken(COMP_ADDRESS, address(this), totalComp);
            totalComp = _distFees(COMP_ADDRESS, totalComp, dfWallet);
            IToken(COMP_ADDRESS).transfer(msg.sender, totalComp);
            wallets[dfWallet].compClaimed += uint64(totalComp / 1e12); // 6 decemals
            emit DfCloseDeposit(dfWallet, totalComp, COMP_ADDRESS);
        }
    }

    function closeDepositFlashloan(address dfWallet, uint256 minUsdForComp, bytes memory data) public {
        require(wallets[dfWallet].owner == msg.sender);
        require(wallets[dfWallet].deposit > 0);

        uint256 startBalance = IToken(DAI_ADDRESS).balanceOf(address(this));

        // FLASHLOAN LOGIC
        uint256 flashLoanAmount = ICToken(CDAI_ADDRESS).borrowBalanceCurrent(dfWallet);
        state = OP.CLOSE;

        if (flashloanProvider == FlashloanProvider.AAVE) {
            ILendingPool lendingPool = ILendingPool(ILendingPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getLendingPool());
            lendingPool.flashLoan(address(this), DAI_ADDRESS, flashLoanAmount, abi.encodePacked(dfWallet));
        } else {
            _initFlashloanDyDx(
                DAI_ADDRESS,
                flashLoanAmount,
                // Encode FlashloanDyDxData for callFunction
                abi.encode(FlashloanDyDxData({dfWallet: dfWallet, deposit: 0, amountFlashLoan: flashLoanAmount}))
            );
        }

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC

        _withdrawBodyAndChangeWalletInfo(dfWallet, sub(IToken(DAI_ADDRESS).balanceOf(address(this)), startBalance));

        // withdraw comp
        if (minUsdForComp > 0) {
            IDfWallet(dfWallet).withdrawToken(COMP_ADDRESS, address(this), IToken(COMP_ADDRESS).balanceOf(dfWallet));
            uint256 amountUsdt = _exchange(IToken(COMP_ADDRESS), IToken(COMP_ADDRESS).balanceOf(dfWallet), IToken(USDT_ADDRESS), minUsdForComp, data);
            amountUsdt = _distFees(USDT_ADDRESS, amountUsdt, dfWallet);
            wallets[dfWallet].compClaimedinUSD += uint64(amountUsdt);
            IToken(USDT_ADDRESS).universalTransfer(msg.sender, amountUsdt);
            emit DfCloseDeposit(dfWallet, amountUsdt, USDT_ADDRESS);
        } else {
            uint256 totalComp = IToken(COMP_ADDRESS).balanceOf(dfWallet);
            IDfWallet(dfWallet).withdrawToken(COMP_ADDRESS, address(this), totalComp);
            if (totalComp > 0) {
                totalComp = _distFees(COMP_ADDRESS, totalComp, dfWallet);
                IToken(COMP_ADDRESS).transfer(msg.sender, totalComp);
            }
            emit DfCloseDeposit(dfWallet, totalComp, COMP_ADDRESS);
        }
    }

    // dont' distribute COMPS
    function partiallyCloseDepositDAI(address dfWallet, address tokenReceiver, uint256 amountDAI) public balanceCheck {
        require(wallets[dfWallet].owner == msg.sender);
        require(wallets[dfWallet].deposit > amountDAI); // not >= cause it closeDeposit
        require(tokenReceiver != address(0x0));

        uint256 startBalance = IToken(DAI_ADDRESS).balanceOf(address(this));

        uint256 flashLoanAmount = amountDAI.mul(3);

        if (IToken(DAI_ADDRESS).allowance(address(this), dfWallet) != uint256(-1)) {
            IToken(DAI_ADDRESS).approve(dfWallet, uint256(-1));
        }

        uint256 cDaiToExtract =  flashLoanAmount.add(amountDAI).mul(1e18).div(ICToken(CDAI_ADDRESS).exchangeRateCurrent());

        IDfWallet(dfWallet).withdraw(DAI_ADDRESS, CDAI_ADDRESS, cDaiToExtract, DAI_ADDRESS, CDAI_ADDRESS, flashLoanAmount);

        // _withdrawBodyAndChangeWalletInfo ?
        uint256 tokensSent = sub(IToken(DAI_ADDRESS).balanceOf(address(this)), startBalance);
        IToken(DAI_ADDRESS).transfer(tokenReceiver, tokensSent); // tokensSent will be less then amountDAI because of fee
        wallets[dfWallet].deposit = wallets[dfWallet].deposit.sub(amountDAI);

        emit DfPartiallyCloseDeposit(dfWallet, tokenReceiver, amountDAI, tokensSent,  wallets[dfWallet].deposit);
    }

    // dont' distribute COMPS
    function partiallyCloseDepositDAIFlashloan(address dfWallet, address tokenReceiver, uint256 amountDAI) public {
        require(wallets[dfWallet].owner == msg.sender);
        require(wallets[dfWallet].deposit > amountDAI); // not >= cause it closeDeposit
        require(tokenReceiver != address(0x0));

        uint256 startBalance = IToken(DAI_ADDRESS).balanceOf(address(this));

        // FLASHLOAN LOGIC
        uint256 flashLoanAmount = amountDAI.mul(3);
        state = OP.PARTIALLYCLOSE;

        if (flashloanProvider == FlashloanProvider.AAVE) {
            ILendingPool lendingPool = ILendingPool(ILendingPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getLendingPool());
            lendingPool.flashLoan(address(this), DAI_ADDRESS, flashLoanAmount, abi.encodePacked(dfWallet));
        } else {
            _initFlashloanDyDx(
                DAI_ADDRESS,
                flashLoanAmount,
                // Encode FlashloanDyDxData for callFunction
                abi.encode(FlashloanDyDxData({dfWallet: dfWallet, deposit: 0, amountFlashLoan: flashLoanAmount}))
            );
        }

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC

        uint256 tokensSent = sub(IToken(DAI_ADDRESS).balanceOf(address(this)), startBalance);
        IToken(DAI_ADDRESS).transfer(tokenReceiver, tokensSent);

        wallets[dfWallet].deposit = wallets[dfWallet].deposit.sub(amountDAI);

        emit DfPartiallyCloseDeposit(dfWallet, tokenReceiver, amountDAI, tokensSent,  wallets[dfWallet].deposit);
    }


    // ** FLASHLOAN CALLBACK functions **

    // Aave flashloan callback
    function executeOperation(
        address _reserve,
        uint256 _amountFlashLoan,
        uint256 _fee,
        bytes memory _data
    ) public {
        require(state != OP.UNKNOWN);

        address dfWallet = _bytesToAddress(_data);

        require(_amountFlashLoan <= getBalanceInternal(address(this), _reserve));

        if (IToken(DAI_ADDRESS).allowance(address(this), dfWallet) != uint256(-1)) {
            IToken(DAI_ADDRESS).approve(dfWallet, uint256(-1));
        }

        uint256 totalDebt = add(_amountFlashLoan, _fee);
        if (state == OP.OPEN) {
            uint256 deposit;
            assembly {
                deposit := mload(add(_data,52))
            }

            uint256 totalFunds = _amountFlashLoan + deposit;

            IToken(DAI_ADDRESS).transfer(dfWallet, _amountFlashLoan);

            IDfWallet(dfWallet).deposit(DAI_ADDRESS, CDAI_ADDRESS, totalFunds, DAI_ADDRESS, CDAI_ADDRESS, totalDebt);

            IDfWallet(dfWallet).withdrawToken(DAI_ADDRESS, address(this), totalDebt); // TODO: remove it
        } else if (state == OP.CLOSE) {
            IDfWallet(dfWallet).withdraw(DAI_ADDRESS, CDAI_ADDRESS, uint256(-1), DAI_ADDRESS, CDAI_ADDRESS, uint256(-1));
        } else if (state == OP.PARTIALLYCLOSE) {
            // _amountFlashLoan.div(3) - user token requested
            uint256 cDaiToExtract =  _amountFlashLoan.add(_amountFlashLoan.div(3)).mul(1e18).div(ICToken(CDAI_ADDRESS).exchangeRateCurrent());

            IDfWallet(dfWallet).withdraw(DAI_ADDRESS, CDAI_ADDRESS, cDaiToExtract, DAI_ADDRESS, CDAI_ADDRESS, _amountFlashLoan);
            // require(_amountFlashLoan.div(3) >= sub(receivedAmount, _fee), "Fee greater then user amount"); // user pay fee for flash loan
        }

        // Time to transfer the funds back
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    // dYdX flashloan callback
    function callFunction(
        address sender,
        Account.Info memory account,
        bytes memory data
    ) public {
        require(state != OP.UNKNOWN);
        FlashloanDyDxData memory flashloanData = abi.decode(data, (FlashloanDyDxData));

        // require(flashloanData.amountFlashLoan <= getBalanceInternal(address(this), DAI_ADDRESS));

        if (IToken(DAI_ADDRESS).allowance(address(this), flashloanData.dfWallet) != uint256(-1)) {
            IToken(DAI_ADDRESS).approve(flashloanData.dfWallet, uint256(-1));
        }

        // Calculate repay amount (_amount + (2 wei))
        uint256 totalDebt = _getRepaymentAmountInternal(flashloanData.amountFlashLoan);
        if (state == OP.OPEN) {
            uint256 totalFunds = flashloanData.amountFlashLoan + flashloanData.deposit;

            IToken(DAI_ADDRESS).transfer(flashloanData.dfWallet, flashloanData.amountFlashLoan);

            IDfWallet(flashloanData.dfWallet).deposit(DAI_ADDRESS, CDAI_ADDRESS, totalFunds, DAI_ADDRESS, CDAI_ADDRESS, totalDebt);

            IDfWallet(flashloanData.dfWallet).withdrawToken(DAI_ADDRESS, address(this), totalDebt);
        } else if (state == OP.CLOSE) {
            IDfWallet(flashloanData.dfWallet).withdraw(DAI_ADDRESS, CDAI_ADDRESS, uint256(-1), DAI_ADDRESS, CDAI_ADDRESS, uint256(-1));
        } else if (state == OP.PARTIALLYCLOSE) {
            // flashloanData.amountFlashLoan.div(3) - user token requested
            uint256 cDaiToExtract =  flashloanData.amountFlashLoan.add(flashloanData.amountFlashLoan.div(3)).mul(1e18).div(ICToken(CDAI_ADDRESS).exchangeRateCurrent());

            IDfWallet(flashloanData.dfWallet).withdraw(DAI_ADDRESS, CDAI_ADDRESS, cDaiToExtract, DAI_ADDRESS, CDAI_ADDRESS, flashloanData.amountFlashLoan);
            // require(flashloanData.amountFlashLoan.div(3) >= sub(receivedAmount, _fee), "Fee greater then user amount"); // user pay fee for flash loan
        }
    }


    // ** PRIVATE & INTERNAL functions **

    function _bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys,20))
        }
    }

    // return new reward balance
    function _distFees(address _token, uint256 _reward, address _dfWallet) internal returns (uint256) {
        uint256 feeReward;
        // calculations based on custom fee scheme
        if (wallets[_dfWallet].activeFeeScheme > 0) {
            uint64 index = wallets[_dfWallet].activeFeeScheme - 1;
            FeeScheme memory scheme = feeSchemes[index];
            if (scheme.isEnabled) {
                feeReward = uint256(scheme.fee) * _reward / 100;
                if (feeReward > 0) {
                    for(uint16 i = 0; i < scheme.partners.length;i++) {
                        partnerBalances[scheme.partners[i]][_token] += feeReward * scheme.percents[i] / 100;
                    }
                }
                return sub(_reward, feeReward);
            }
        }
        // global fee scheme
        feeReward = uint256(fee) * _reward / 100;
        if (feeReward > 0) partnerBalances[owner][_token] += feeReward;

        return sub(_reward, feeReward);
    }

    function _exchange(
        IToken _fromToken, uint _maxFromTokenAmount, IToken _toToken, uint _minToTokenAmount, bytes memory _data
    ) internal returns(uint) {

        IOneInchExchange ex = IOneInchExchange(0x11111254369792b2Ca5d084aB5eEA397cA8fa48B); // TODO: set state var

        if (_fromToken.allowance(address(this), address(ex.spender())) != uint256(-1)) {
            _fromToken.approve(address(ex.spender()), uint256(-1));
        }

        uint fromTokenBalance = _fromToken.universalBalanceOf(address(this));
        uint toTokenBalance = _toToken.universalBalanceOf(address(this));

        // Proxy call for avoid out of gas in fallback (because of .transfer())
        // proxyEx.exchange(_fromToken, _maxFromTokenAmount, _data);
        bytes32 response;
        assembly {
            // call(g, a, v, in, insize, out, outsize)
            let succeeded := call(sub(gas, 5000), ex, 0, add(_data, 0x20), mload(_data), 0, 32)
            response := mload(0)      // load delegatecall output
        }

        require(_fromToken.universalBalanceOf(address(this)) + _maxFromTokenAmount >= fromTokenBalance, "Exchange error 1");

        uint256 newBalanceToToken = _toToken.universalBalanceOf(address(this));
        require(newBalanceToToken >= toTokenBalance + _minToTokenAmount, "Exchange error 2");

        return sub(newBalanceToToken, toTokenBalance); // how many tokens received
    }

    function _withdrawBodyAndChangeWalletInfo(address dfWallet, uint256 userBalance) internal {
        IToken(DAI_ADDRESS).transfer(wallets[dfWallet].owner, userBalance); // withdraw original dai amount
        if (userBalance > wallets[dfWallet].deposit) {
            wallets[dfWallet].deposit = 0;
        } else {
            wallets[dfWallet].deposit = sub(wallets[dfWallet].deposit, userBalance);
        }
    }


    // **FALLBACK functions**
    function() external payable {}

}