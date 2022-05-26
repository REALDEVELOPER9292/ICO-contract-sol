// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * mul 
     * @dev Safe math multiply function
     */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  /**
   * add
   * @dev Safe math addition function
   */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

abstract contract Ownable {
  address public owner;

  constructor () internal {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
  }
}

/**
 * @title Token
 * @dev API interface for interacting with the WILD Token contract 
 */
interface IToken {
  function transfer(address _to, uint256 _value) external returns (bool);
  function balanceOf(address _owner) external returns (uint256 balance);
}

/**
 * @title NowMetaICO
 * @dev NowMetaICO contract is Ownable
 **/
contract NowMetaICO is Ownable {
  using SafeMath for uint256;

  struct TokenInfo {
    uint256 rate;
    uint256 cap;
    uint256 start;
    uint256 day;
    uint256 initialToken;
    bool initialized;
    uint256 raisedAmount;
  }
  
  mapping(address => TokenInfo) public Tokens;

  mapping(address =>  mapping(address => uint256)) public UserInfo;

  event BoughtTokens(address indexed to, uint256 value);

  constructor(
    address _tokenaddr,
    uint256 rate,
    uint256 cap,
    uint256 start,
    uint256 day,
    uint256 initialToken,
    bool initialized
  ) public {
    Tokens[_tokenaddr] = TokenInfo(rate, cap, start, day, initialToken, initialized, 0);
  }


  function addToken(
      address _tokenaddr,
      uint256 rate,
      uint256 cap,
      uint256 start,
      uint256 day,
      uint256 initialToken,
      bool initialized
  ) external onlyOwner returns (bool) {
    Tokens[_tokenaddr] = TokenInfo(rate, cap, start, day, initialToken, initialized, 0);
    return true;
  }
  
  function initialize(address _tokenAddr) public onlyOwner {
    TokenInfo storage _token = Tokens[_tokenAddr];
    require(_token.initialized == false, "Can only be initialized once"); // Can only be initialized once
    require(tokensAvailable(_tokenAddr) > _token.initialToken, "Must have enough tokens allocated"); // Must have enough tokens allocated
    
    _token.initialized = true;
  }

  modifier beforeBuy(address _tokenAddr) {
    require(isActive(_tokenAddr), "Not activated");
    _;
  }

  function isActive(address _tokenAddr) public view returns (bool) {
    TokenInfo storage _token = Tokens[_tokenAddr];
    return (
        _token.initialized == true &&
        now >= _token.start && // Must be after the START date
        now <= _token.start.add(_token.day * 1 days) // Must be before the end date
    );
  }

  function buyTokens(address _tokenAddr) public payable beforeBuy(_tokenAddr) {
    TokenInfo storage _token = Tokens[_tokenAddr];
    uint256 purchased = UserInfo[msg.sender][_tokenAddr];
    uint256 weiAmount = msg.value; // Calculate tokens to sell
    
    require(purchased.add(weiAmount) < _token.cap, "error : overflow purchased Amount");

    uint256 tokens = weiAmount.mul(_token.rate);
    
    _token.raisedAmount = _token.raisedAmount.add(weiAmount); // Increment raised amount
    IToken token = IToken(_tokenAddr);
    token.transfer(msg.sender, tokens); // Send tokens to buyer
    UserInfo[msg.sender][_tokenAddr] = purchased.add(weiAmount);

    payable(owner).transfer(weiAmount);// Send money to owner
    
    emit BoughtTokens(msg.sender, tokens); // log event onto the blockchain
  }

  function tokensAvailable(address _tokenAddr) public returns (uint256) {
    IToken token = IToken(_tokenAddr);
    return token.balanceOf(address(this));
  }

  function destroy(address _tokenAddr) onlyOwner public {
    IToken token =  IToken(_tokenAddr);
    uint256 balance = token.balanceOf(address(this));
    assert(balance > 0);
    token.transfer(owner, balance);
  }
}
