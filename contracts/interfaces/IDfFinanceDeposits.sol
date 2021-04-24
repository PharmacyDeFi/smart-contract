
pragma solidity ^0.5.16;

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
