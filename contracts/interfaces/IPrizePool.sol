// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./ITicket.sol";

interface IPrizePool {

    event ResultSet(uint32 indexed drawId, uint8 result);

    /// @dev Event emitted when assets are deposited
    event Deposited(
        address indexed user,
        ITicket indexed token,
        uint256 amount
    );

    event ClaimedDraw(address indexed user, uint32 indexed drawId, uint256 payout);

    /// @notice Deposit assets into the Prize Pool in exchange for tokens
    /// @param bet The choice that user makes
    function depositTo(bool bet) external payable;

    // @dev Returns the total underlying balance of all assets.
    /// @return The underlying balance of assets
    function balance() external view returns (uint256);

    /**
     * @notice Read internal Ticket accounted balance.
     * @return uint256 accountBalance
     */
    function getAccountedBalance(bool bet) external view returns (uint256);

    /**
     * @notice Read ticket variable
     */
    function getTicket(bool _bet) external view returns (ITicket);

    /// @notice Set prize pool ticket.
    /// @param yesTicket Address of the yes ticket to set.
    /// @param noTicket Address of the no ticket to set.
    /// @return True if ticket has been successfully set.
    function setTicket(ITicket yesTicket, ITicket noTicket) external returns (bool);

    function getResults() external view returns (uint8[] memory);

    /// will be called by Defender autotask, 1 in The Unit, -1 not in
    function pushResult(uint8 result) external returns (bool);

    function claim() external returns (uint256);

    /**
     * @notice Returns the number of seconds remaining until the beacon period can be complete.
     * @return The number of seconds remaining until the beacon period can be complete.
     */
    function drawRemainingSeconds() external view returns (uint256);

    /**
     * @notice Returns the timestamp at which the beacon period ends
     * @return The timestamp at which the beacon period ends.
     */
    function drawPeriodEndAt() external view returns (uint256);

    /**
     * @notice Returns whether the beacon period is over
     * @return True if the beacon period is over, false otherwise
     */
    function isDrawOver() external view returns (bool);

    /**
     * @return The draw id.
     */
    function getDrawId() external view returns (uint32);

    /**
     * @return The bet coin.
     */
    function getBetCoin() external view returns (string memory);
}
