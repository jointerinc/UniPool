pragma solidity =0.5.16;

import './UniswapV2Pair.sol';
import "./Ownable.sol";

contract UniswapV2Factory is Ownable {

    address public constant BNB = 0x0000000000000000000000000000000000000001;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    mapping(address => bool) isAllowedAddress;
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function changeAllowedAddress(address _which,bool _bool) external onlyOwner returns(bool){
        isAllowedAddress[_which] = _bool;
        return true;
    }


    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) public returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function cratePool(address tokenA, address tokenB, uint amountA, uint amountB, address payable to) external payable returns(address pair, uint liquidity) {
        pair = createPair(tokenA, tokenB);
        bool isBNB;
        if (tokenA == BNB) isBNB = true;
        else safeTransferFrom(tokenA, msg.sender, pair, amountA);

        if (tokenB == BNB) isBNB = true;
        else safeTransferFrom(tokenB, msg.sender, pair, amountB);

        if (isBNB) liquidity = IUniswapV2Pair(pair).mint.value(msg.value)(to);
        else liquidity = IUniswapV2Pair(pair).mint(to);
    }

    function mint(address tokenA, address tokenB, uint amountA, uint amountB, address payable to) external payable returns(uint liquidity) {
        require(isAllowedAddress[msg.sender],"ERR_ALLOWED_ADDRESS_ONLY");
        address pair = getPair[tokenA][tokenB];
        bool isBNB;
        if (tokenA == BNB) isBNB = true;
        else safeTransferFrom(tokenA, msg.sender, pair, amountA);

        if (tokenB == BNB) isBNB = true;
        else safeTransferFrom(tokenB, msg.sender, pair, amountB);

        if (isBNB) liquidity = IUniswapV2Pair(pair).mint.value(msg.value)(to);
        else liquidity = IUniswapV2Pair(pair).mint(to);
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairAddressFor(address tokenA, address tokenB) external view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 bytecodeHash = keccak256(bytecode);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                address(this),
                keccak256(abi.encodePacked(token0, token1)),
                bytecodeHash    // hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }
}
