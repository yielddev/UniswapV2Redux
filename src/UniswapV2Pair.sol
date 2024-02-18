// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.20;

import {IUniswapV2Pair} from './interfaces/IUniswapV2Pair.sol';
import {IUniswapV2Factory} from './interfaces/IUniswapV2Factory.sol';
import {ERC20} from "@vectorized/solady@v0.0.165/tokens/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts@v5.0.0/utils/math/Math.sol";
import {UQ112x112} from './libraries/UQ112x112.sol';
import { ReentrancyGuard } from "@openzeppelin/contracts@v5.0.0/utils/ReentrancyGuard.sol";
import { IERC3156FlashLender } from '@openzeppelin/contracts@v5.0.0/interfaces/IERC3156FlashLender.sol';
import { IERC3156FlashBorrower } from "@openzeppelin/contracts@v5.0.0/interfaces/IERC3156FlashBorrower.sol";
import "forge-std/console.sol";
// import {UQ112x112} from './libraries/UQ112x112.sol';

error UniswapV2__INSUFFICIENT_OUTPUT_AMOUNT();
error UniswapV2__INSUFFICIENT_LIQUIDITY();
error UniswapV2__INSUFFICIENT_LIQUIDITY_MINTED();
error UniswapV2__INSUFFICIENT_TOKEN0_AMOUNT();
error UniswapV2__INSUFFICIENT_TOKEN1_AMOUNT();
error UniswapV2__OPTMIAL_AMOUNT_GREATER_THAN_DESIRED();
error UniswapV2__INVALID_DESTINATION();
error UniswapV2__INVALID_TOKEN();
error UniswapV2__INSUFFICIENT_INPUT_AMOUNT();
error UniswapV2__INSUFFICIENT_LIQUIDITY_BURNED();
error UniswapV2__TRANSFER_FAILED();
error UniswapV2__EXPIRED();
error UniswapV2__K();
error UniswapV2__FlashLoanCallbackFailed();
error UniswapV2_FlashLoanPaymentFailed();
contract UniswapV2Pair is IUniswapV2Pair, ERC20, IERC3156FlashLender, ReentrancyGuard {
    using UQ112x112 for uint224;
    using Math for uint;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint public constant FEE = 30;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
//        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
        if(!success && (data.length == 0 || abi.decode(data, (bool)))) revert UniswapV2__TRANSFER_FAILED();
    }

    constructor() ERC20(){
        factory = msg.sender;
    }

    function name() public view override returns (string memory) { return "Uniswap V2"; }
    function symbol() public view override returns (string memory) { return "UNI-V2"; }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // overflow is desired, thus unchecked
            unchecked {
                price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = address(0);//IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0) * (_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply() * (rootK - rootKLast);
                    uint denominator = rootK * 3 + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function maxFlashLoan(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    function flashFee(address token, uint256 amount) public view returns (uint256) {
        // flat rate 1000000 wei
        return 1000000;
    }
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override returns(bool){
        if (token != token0 && token != token1) revert UniswapV2__INVALID_TOKEN();
        uint256 fee = flashFee(token, amount);
        IERC20(token).transfer(address(receiver), amount);
        if(receiver.onFlashLoan(msg.sender, token, amount, fee, data) != keccak256("ERC3156FlashBorrower.onFlashLoan")) revert UniswapV2__FlashLoanCallbackFailed();
        if (IERC20(token).transferFrom(address(receiver), address(this), amount + fee) != true) revert UniswapV2_FlashLoanPaymentFailed();
        return true;

    }
    function mint(
        address to,
        uint amount0Desired,
        uint amount1Desired,
        uint amount0Min,
        uint amount1Min
        ) external nonReentrant returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint amount0;
        uint amount1;
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {// get optimal
            uint amount1Optimal = amount0Desired * _reserve1 / _reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert UniswapV2__INSUFFICIENT_TOKEN0_AMOUNT();
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint amount0Optimal = (amount1Desired * _reserve0) / _reserve1;
                // change error code
                if (amount0Optimal > amount0Desired) revert UniswapV2__INSUFFICIENT_TOKEN1_AMOUNT();
                if (amount0Optimal < amount0Min) revert UniswapV2__INSUFFICIENT_TOKEN1_AMOUNT();
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
        // transfer in
        if(!ERC20(token0).transferFrom(msg.sender, address(this), amount0)) revert UniswapV2__TRANSFER_FAILED();
        if(!ERC20(token1).transferFrom(msg.sender, address(this), amount1)) revert UniswapV2__TRANSFER_FAILED();

        uint balance0 = ERC20(token0).balanceOf(address(this));
        uint balance1 = ERC20(token1).balanceOf(address(this));
        amount0 = balance0 - _reserve0;
        amount1 = balance1 - _reserve1;
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        if (liquidity <= 0) revert UniswapV2__INSUFFICIENT_LIQUIDITY_MINTED();
        _mint(to, liquidity);
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * (reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }
    function burn(
        address to,
        uint liquidity,
        uint amount0Min,
        uint amount1Min,
        uint deadline
        ) external nonReentrant returns (uint amount0, uint amount1) {
        if (block.timestamp > deadline) revert UniswapV2__EXPIRED();
        if(!IERC20(address(this)).transferFrom(msg.sender, address(this), liquidity)) revert UniswapV2__TRANSFER_FAILED(); // send liquidity to pair
        console.log("here");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        console.log("here");
        //address _token0 = token0;                                // gas savings
        //address _token1 = token1;                                // gas savings
        uint balance0 = ERC20(token0).balanceOf(address(this));
        uint balance1 = ERC20(token1).balanceOf(address(this));
        liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply();
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution

        if(amount0 < amount0Min) revert UniswapV2__INSUFFICIENT_TOKEN0_AMOUNT();
        if(amount1 < amount1Min) revert UniswapV2__INSUFFICIENT_TOKEN1_AMOUNT();

        if (amount0 <= 0 && amount1 <= 0) revert UniswapV2__INSUFFICIENT_LIQUIDITY_BURNED();
        _burn(address(this), liquidity);

        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);
        // if(!ERC20(token0).transfer(to, amount0)) revert UniswapV2__TRANSFER_FAILED();
       // if(!ERC20(token1).transfer(to, amount1)) revert UniswapV2__TRANSFER_FAILED();
        balance0 = ERC20(token0).balanceOf(address(this));
        balance1 = ERC20(token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * (reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address tokenIn,
        address to,
        uint deadline
    ) external nonReentrant {
        if (block.timestamp > deadline) revert UniswapV2__EXPIRED();
        uint amountInWithFee = amountIn * (10000 - FEE);
        uint reserveOut = tokenIn == token0 ? reserve1 : reserve0;
        uint reserveIn = tokenIn == token0 ? reserve0 : reserve1;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 10000 + amountInWithFee;
        uint amountOut = numerator.ceilDiv(denominator);
        if (amountOut < amountOutMin) revert UniswapV2__INSUFFICIENT_OUTPUT_AMOUNT();
        if(!IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn)) revert UniswapV2__TRANSFER_FAILED();
        (uint amount0Out, uint amount1Out) = tokenIn == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
        swap(amount0Out, amount1Out, to);


    }
    // add slippage 
    function swap(uint amount0Out, uint amount1Out, address to) private {
        if (amount0Out <= 0 && amount1Out <= 0) revert UniswapV2__INSUFFICIENT_OUTPUT_AMOUNT(); 

        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings 

        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) revert UniswapV2__INSUFFICIENT_LIQUIDITY();

        uint balance0;
        uint balance1;

        uint amount0In;
        uint amount1In;
        // Block one 
        {
        address _token0 = token0;
        address _token1 = token1;
        if(to == _token0 || to == _token1) revert UniswapV2__INVALID_DESTINATION();

        // optimistic transfer here?
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);

        balance0 = ERC20(token0).balanceOf(address(this));
        balance1 = ERC20(token1).balanceOf(address(this));
        }

        amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        if (amount0In <= 0 && amount1In <= 0) revert UniswapV2__INSUFFICIENT_INPUT_AMOUNT();
        {

        }

        {
        uint256 balance0Adjusted = balance0 * 10000 - amount0In * 30;
        uint256 balance1Adjusted = balance1 * 10000 - amount1In * 30;
        if(balance0Adjusted * (balance1Adjusted) < uint(_reserve0) * (_reserve1)) revert UniswapV2__K();
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
        
    }

    function skim(address to) external nonReentrant {
        //
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(_token0, to, ERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, ERC20(_token1).balanceOf(address(this)) - reserve1);

    }

    function sync() external nonReentrant {
        _update(ERC20(token0).balanceOf(address(this)), ERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
    
    
}

