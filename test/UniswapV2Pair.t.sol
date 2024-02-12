// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {MockToken} from "../src/mocks/MockToken.sol";
import {Math} from "@openzeppelin/contracts@v5.0.0/utils/math/Math.sol";
import "forge-std/console.sol";
contract UniswapV2PairTest is Test {

    using Math for uint256;
    address public OwnerWallet;
    address public UserWallet;
    address public lp;
    UniswapV2Pair pair;
    MockToken token0;
    MockToken token1;
    function setUp() public {
        OwnerWallet = address(69);
        UserWallet = address(420);
        lp = address(666);

        vm.deal(UserWallet, 1000 ether);
        vm.deal(lp, 1000 ether);

        token0 = new MockToken(address(this));
        token1 = new MockToken(address(this));
        token0.mint(address(this), 1010 ether);
        token1.mint(address(this), 1000 ether);
        token0.mint(address(lp), 100 ether);
        token1.mint(address(lp), 100 ether);
        token0.mint(address(UserWallet), 100 ether);
        token1.mint(address(UserWallet), 100 ether);

        pair = new UniswapV2Pair();

        pair.initialize(address(token0), address(token1));
        //token0.approve(address(pair), 1000 ether);
        //token1.approve(address(pair), 1000 ether);
        //pair.mint(address(this), 100 ether, 100 ether, 0, 0);
    } 
    function setUpLiquidity() public {
        vm.startPrank(lp);
        token0.approve(address(pair), 100 ether);
        token1.approve(address(pair), 100 ether);
        pair.mint(address(lp), 100 ether, 100 ether, 0, 0);
        vm.stopPrank();
    }
    function test_initialMint() public {
        // initial liquidity 100 token0 : 10 token1
        // token1 price 10token0s
        // min liq = 1,000
        // inital lp = (100 * 10) = sqrt(1,000 ether) - 1,000 = 0
        // 31.6227766017*(10**18) - 1000 = 
        // 3.16227766017e+19 - 1000 = 3.16227766017e+19
        vm.startPrank(lp);
        token0.approve(address(pair), 100 ether);
        token1.approve(address(pair), 100 ether);
        pair.mint(address(lp), 100 ether, 10 ether, 0, 0);
        uint256 expectedLPmint = Math.sqrt(100 ether * 10 ether) - 1000;
        assertEq(expectedLPmint, pair.balanceOf(address(lp)));
        vm.stopPrank();
    }
    function test_burn() public {
        setUpLiquidity();
        uint256 lpBalance = pair.balanceOf(address(lp));
        uint256 burnAmount = lpBalance / 10;
        uint256 lpSupply = pair.totalSupply();

        uint256 token0Balance = token0.balanceOf(address(pair));
        uint256 token1Balance = token1.balanceOf(address(pair));
        uint256 token0user = token0.balanceOf(address(lp));
        uint256 token1user = token1.balanceOf(address(lp));
        uint256 token0redeem = burnAmount * token0Balance / lpSupply;
        uint256 token1redeem = burnAmount * token1Balance / lpSupply;
        vm.startPrank(lp);
        pair.approve(address(pair), UINT256_MAX);
        pair.burn(address(lp), burnAmount, 0, 0, 10000000000);
        assertEq(pair.balanceOf(address(lp)), lpBalance - burnAmount);
        assertEq(token0.balanceOf(address(lp)), token0user + token0redeem);
        assertEq(token1.balanceOf(address(lp)), token1user + token1redeem);
        vm.stopPrank();
        // burn 10% of LP
        // 10% of 1000 = 100
        // 100 token0 : 10
    }
    function test_test() public {
        setUpLiquidity();
        console.log("foo");
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();

        // expected out for 8 tokens in 
        uint amountIn = 8 ether;
        uint amountInWithFee = amountIn * 9970;
        uint amountOutexpected = ((amountInWithFee) * reserve1).ceilDiv(reserve0*10000 + amountInWithFee);
        uint startingBalance = token1.balanceOf(address(UserWallet));
        console.log("reserve0: ", reserve0);
        console.log("reserve1: ", reserve1);
        console.log("blockTimestampLast: ", blockTimestampLast);
        console.log(address(UserWallet));
        vm.startPrank(UserWallet);
        //token0.approve(address(this), 100 ether);
        // deal with transfer in 
        token0.approve(address(pair), 100 ether);
        // pair.swap(0 ether, 8 ether, address(UserWallet), "");
        pair.swapExactTokensForTokens(8 ether, 0 ether, address(token0), address(UserWallet), 10000000000);
        assertEq(token1.balanceOf(address(UserWallet)), startingBalance + amountOutexpected);

        // pair.swap(0 ether, 8 ether, address(UserWallet), "");
        // pair.swap(0 ether, 8 ether, address(UserWallet), "");
    }

    // mint tests
    // test initial liq
    // test mint amounts and LPs

    // function test_swap()

    // function swap amounts




}
