// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract FundMeTest is StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    uint256 public constant SEND_VALUE = 0.1 ether; // just a value to make sure we are sending enough!
    // uint256 public constant SEND_VALUE = 1e18;
    // uint256 public constant SEND_VALUE = 1_000_000_000_000_000_000;
    // uint256 public constant SEND_VALUE = 1000000000000000000;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1; // to be used in vm.txGasPrice()

    address public constant USER = address(1);

    function setUp() external {
        //fundMe = new FundMe(); // no parameters in the constructor of FundMe()
        DeployFundMe deployer = new DeployFundMe();
        //fundMe = deployer.run();
        (fundMe, helperConfig) = deployer.run();

        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        //console.log(fundMe.i_owner());
        console.log(fundMe.getOwner());
        console.log(address(this));
        //assertEq(fundMe.i_owner(), msg.sender);
        // assertEq(fundMe.i_owner(), address(this)); // FundMeTest is the owner

        //assertEq(fundMe.i_owner(), msg.sender); // after refactoring your tests
        assertEq(fundMe.getOwner(), msg.sender); // after refactoring your tests
    }

    function testPriceFeedSetCorrectly() public {
        address retreivedPriceFeed = address(fundMe.getPriceFeed());
        // (address expectedPriceFeed) = helperConfig.activeNetworkConfig();
        address expectedPriceFeed = helperConfig.activeNetworkConfig();
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion(); // this will fail bec the price feed
        // is not existing in Anvil. So what we did is to create "anvilConfig" in HelperConfig
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // hey the next line, should revert. So force it not to satisfy the condition of the require in fund function.
        fundMe.fund(); // zero value
    }

    // Notes on who is doing what. Who is calling the function? Is is msg.sender or anyone else?
    // Who is sending which transactions
    function testFundUpdatesFundedDataStructure() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        address funder = fundMe.getFunder(0); // this is for the USER as
        assertEq(funder, USER);
    }

    // https://twitter.com/PaulRBerg/status/1624763320539525121

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        // 1. Arrange
        uint256 startingFundMeBalance = address(fundMe).balance; // balance of the contract
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        // IMPORTANT #1
        // vm.txGasPrice(GAS_PRICE);
        // uint256 gasStart = gasleft();  // gasLeft() is built-in function in solidity
        // 2. Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // IMPORTANT #2
        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);

        // 3. Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance // + gasUsed
        );
    }

    // Can we do our withdraw function a cheaper way?
    function testWithdrawFromMultipleFunders() public funded {
        // if you want to work with addresses, if you want to use numbers to generate addresses, those numbers has to be in uint160
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2; // dont start '0'

        // here we can create address(0), (1), (2) and so on
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_USER_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    // this is copy of testWithdrawFromMultipleFunders()
    // the only difference is fundMe.cheaperWithdraw();
    function testWithdrawFromMultipleFundersCheaper() public funded {
        // if you want to work with addresses, if you want to use numbers to generate addresses, those numbers has to be in uint160
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2; // dont start '0'

        // here we can create address(0), (1), (2) and so on
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_USER_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }
}
