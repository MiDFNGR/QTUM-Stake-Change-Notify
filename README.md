# QTUM-Stake-Change-Notify

A Bash script to monitor QTUM wallet and send stake-change notifications to text and email.

Text message notifications are sent as email-to-text. For example, the format of a T-Mobile email-to-text address is: 5551234567@tmomail.net

An email message is also sent to a standard address with the full wallet "getinfo".

Additional features:
- Stake-change notifications are delayed for 6 confirmations (blocks).  This should greatly reduce notifications of staked blocks that later become orphaned.
- The script is built to be self-aware. This means that if the script runs while another instance is still running, it will detect that and exit.  This is to prevent multiple instances from running while the script is waiting for 6 confirmations.
- "Wallet-Locked" notifications will be sent if the script finds the QTUM wallet "locked", which can happen after an unexpected reboot of the Raspberry Pi.  To prevent spamming yourself, no more "locked" notifications will be sent until after the script has found the wallet "unlocked" at least once.
