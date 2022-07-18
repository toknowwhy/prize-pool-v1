// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IPrizePool.sol";
import "./interfaces/ITicket.sol";

/**
  * @title  The Unit PrizePool
  * @author The Unit
  * @notice People can bet in this prize pool on which coin will get in / fall out from The Unit
*/
contract PrizePool is IPrizePool, Ownable, AccessControl, ReentrancyGuard {
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using ERC165Checker for address;

    /// @notice Semver Version
    string public constant VERSION = "1.0.0";

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Prize Pool ticket. Can only be set once by calling `setTicket()`.
    ITicket internal yesTicket;
    ITicket internal noTicket;

    string internal betCoin;

    /// @notice Seconds between beacon period request
    uint32 internal drawPeriodSeconds;

    /// @notice Epoch timestamp when beacon period can start
    uint256 internal drawPeriodStartedAt;

    /**
     * @dev Starts at 1. This way we know that no Draw has been recorded at 0.
     */
    uint32 internal drawId;
    
    uint8 public constant TIERS_LENGTH = 13;

    int8[] internal results;

    uint256 internal finalBalance;
    uint256 internal finalYesBalance;
    uint256 internal finalNoBalance;

    /* ============ Constructor ============ */

    /// @notice Deploy the Prize Pool
    /// @param _manager Address of the Prize Pool manager, who will set result everyday.
    /// @param _drawId The id of this round.
    /// @param _betCoin The coin to bet in this round
    /// @param _beaconPeriodStart The time this round starts.
    /// @param _drawPeriodSeconds The duration of this round.
    constructor(
        address _manager,
        uint32 _drawId,
        string memory _betCoin,
        uint256 _beaconPeriodStart,
        uint32 _drawPeriodSeconds
    ) ReentrancyGuard() {
        drawId = _drawId;
        betCoin = _betCoin;
        drawPeriodStartedAt = _beaconPeriodStart;
        drawPeriodSeconds = _drawPeriodSeconds;
        finalBalance = 0;
        finalYesBalance = 0;
        finalNoBalance = 0;
        _setupRole(MANAGER_ROLE, _manager);
    }

    /* ============ External Functions ============ */

    /// @inheritdoc IPrizePool
    function balance() external view override returns (uint256) {
        return _balance();
    }

    /// @inheritdoc IPrizePool
    function getAccountedBalance(bool _bet) external view override returns (uint256) {
        return _ticketSupply(_bet);
    }

    /// @inheritdoc IPrizePool
    function getTicket(bool _bet) external view override returns (ITicket) {
        return _bet ? yesTicket : noTicket;
    }

    /// @inheritdoc IPrizePool
    function depositTo(bool _bet)
        external
        payable
        override
        nonReentrant
    {
        require(!_isDrawOver(), "This round has ended!");
        require(msg.value >= 10 ** 16, "Minimum deposit is 0.01!");

        ITicket _ticket = _bet ? yesTicket : noTicket;
        _mint(msg.sender, msg.value, _ticket);

        emit Deposited(msg.sender, _ticket, msg.value);
    }

    /// @inheritdoc IPrizePool
    function setTicket(ITicket _yesTicket, ITicket _noTicket) external override onlyOwner returns (bool) {
        require(address(_yesTicket) != address(0), "Ticket cannot be zero address");
        require(address(_noTicket) != address(0), "Ticket cannot be zero address");
        require(address(yesTicket) == address(0), "Ticket already set!");
        require(address(noTicket) == address(0), "Ticket already set!");

        yesTicket = _yesTicket;
        noTicket = _noTicket;

        return true;
    }

    /**
     * @notice Returns the timestamp at which the beacon period ends
     * @return The timestamp at which the beacon period ends
     */
    function _drawPeriodEndAt() internal view returns (uint256) {
        return drawPeriodStartedAt + drawPeriodSeconds;
    }

    function drawPeriodEndAt() external view override returns (uint256) {
        return _drawPeriodEndAt();
    }

    /**
     * @notice Returns the number of seconds remaining until the prize can be awarded.
     * @return The number of seconds remaining until the prize can be awarded.
     */
    function drawRemainingSeconds() external view override returns (uint256) {
        uint256 endAt = _drawPeriodEndAt();
        uint256 time = _currentTime();

        if (endAt <= time) {
            return 0;
        }

        return endAt - time;
    }

    /// @inheritdoc IPrizePool
    function getDrawId() external view override returns (uint32) {
        return drawId;
    }

    function getBetCoin() external view override returns (string memory) {
        return betCoin;
    }

    /// @inheritdoc IPrizePool
    function isDrawOver() external view override returns (bool) {
        return _isDrawOver();
    }

    /// @inheritdoc IPrizePool
    function claim() external override returns (uint256) {
        require(_isDrawOver(), "This round has not ended yet!");
        bool isEntering = !_hasNo();
        uint256 totalBalance = _ticketSupply(isEntering);
        ITicket ticket = isEntering ? yesTicket : noTicket;
        uint256 userBalance = ticket.balanceOf(msg.sender);

        if (userBalance > 0) {
            uint256 totalAssets = _balance();
            ticket.controllerBurn(msg.sender, userBalance);
            uint256 payout = totalAssets.mul(userBalance.div(totalBalance));
            (bool sent,) = msg.sender.call{value: payout}("Sent");
            require(sent, "failed to claim ETH");
        }
        return userBalance;

    }

    /* ============ Internal Functions ============ */


    /// @notice Called to mint controlled tokens.  Ensures that token listener callbacks are fired.
    /// @param _to The user who is receiving the tokens
    /// @param _amount The amount of tokens they are receiving
    /// @param _controlledToken The token that is going to be minted
    function _mint(
        address _to,
        uint256 _amount,
        ITicket _controlledToken
    ) internal {
        _controlledToken.controllerMint(_to, _amount);
    }

    /// @notice The current total of tickets.
    /// @return Ticket total supply.
    function _ticketSupply(bool _bet) internal view returns (uint256) {
        uint256 _finalBalance = _bet ? finalYesBalance : finalNoBalance;
        if (_finalBalance > 0) {
            return _finalBalance;
        } 
        ITicket _ticket = _bet ? yesTicket : noTicket;
        return _ticket.totalSupply();
    }

    function _ticketTotalSupply() internal view returns (uint256) {
        return _ticketSupply(true) + _ticketSupply(false);
    }

    /// @dev Gets the current time as represented by the current block
    /// @return The timestamp of the current block
    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function pushResult(int8 _result) external override onlyRole(MANAGER_ROLE) returns (bool) {
        require(!_isDrawOver(), "This round has ended!");
        results.push(_result);
        if (_isDrawOver()) {
            finalBalance = _balance();
            finalYesBalance = _ticketSupply(true);
            finalNoBalance = _ticketSupply(false);
            emit LastResultSet(drawId, _result, finalBalance, finalYesBalance, finalNoBalance);
        }
        emit ResultSet(drawId, _result);
        return true;
    }

    function getResults() external view override returns (int8[] memory) {
        return results;
    }

    /**
     * @notice Returns whether the beacon period is over.
     * @return True if the beacon period is over, false otherwise
     */
    function _isDrawOver() internal view returns (bool) {

        return _drawPeriodEndAt() <= _currentTime() || _hasNo() || results.length == TIERS_LENGTH;
    }

    function _hasNo() internal view returns (bool) {
        for (uint j=0; j<results.length; j++) {
            if (results[j] == -1) {
                return true;
            }
        }
        return false;
    }

    function _balance() internal view returns (uint256) {
        if (finalBalance > 0) {
            return finalBalance;
        }
        return address(this).balance;
    }

}
