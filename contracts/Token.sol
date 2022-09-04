// SPDX-License-Identifier: All Rights Reserved

pragma solidity ^0.8.16;

contract Token {

    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;
    mapping(address => uint) public tokenHolderTimestamp;

    string public name = "Test BNB";
    string public symbol = "Test BNB";
    uint public decimals = 9;
    uint public initialSupply = 1000000 * (10 ** decimals);
    // founder tax percent
    uint public founderTaxPercent = 5;
    // marketing tax percent
    uint public marketingTaxPercent = 5;
    // amount of bonus tokens person entitled to per period
    uint public rewardPerPeriod = 500 * (10 ** decimals);
    // how often rewards are applied, in days
    uint public rewardPeriod = 30;
    // whether reward tokens are enabled or not
    bool rewardsEnabled;

    event Transfer(address from, address indexed to, uint value);
    event Approval(address owner, address indexed spender, uint value);

    address public contractOwner;
    address public marketingAccount;
    address public founderAccount;

    constructor(address _marketingAccount, address _founderAccount) {
        balances[msg.sender] = initialSupply;
        // here we set the owner variable to the contract deployer address
        contractOwner = msg.sender;
        marketingAccount = _marketingAccount;
        founderAccount = _founderAccount;
    }

    //modifier added that checks that the sender is the owner account
    modifier onlyOwner(){
        require(msg.sender == contractOwner);
        _;
    }

    //here we modify the balanceOf function so that a user's balance is increased
    //by 500 each month that has elapsed since their holding timstamp
    function balanceOf(address owner) public view returns(uint) {
        uint totalBalance;
        // if user has held tokens for >0 amount of time calculate rewards
        if (tokenHolderTimestamp[owner] != 0 || rewardsEnabled) {
            //calc amount of months tokens held
            uint periodsElapsed = (block.timestamp - tokenHolderTimestamp[owner])/(rewardPeriod * 1 days);
            //calc amount of reward tokens
            uint rewardTokens = rewardPerPeriod * periodsElapsed;
            //calc total balance
            totalBalance = balances[owner] + rewardTokens;
        //if token holder has no timestamp, return the raw balance
        } else if (tokenHolderTimestamp[owner] == 0) {
            totalBalance = balances[owner];
        }
        return totalBalance;
    }

    function totalSupply() public view returns(uint) {
        return initialSupply;
    }

    function transfer(address to, uint value) public returns(bool) {

        require(balanceOf(msg.sender) >= value, 'balance too low');

        // calculate bonus allocation so we can prevent it from being deducted from balances mapping
        uint rewardTokens;

        // check if token holden timestamp is set, if it is then they have been holding tokens and are entitled to holding reward tokens
        if (tokenHolderTimestamp[msg.sender] != 0) {
            //calc amount of months tokens held
            uint periodsElapsed = (block.timestamp - tokenHolderTimestamp[msg.sender])/(30 days);
            //calc amount of reward tokens
            rewardTokens = rewardPerPeriod * periodsElapsed;
        //if token holder has no timestamp, return the raw balance
        } else if (tokenHolderTimestamp[msg.sender] == 0) {
            rewardTokens = 0;
        }

        // transfer amount - 2*5% = 90% to recipient
        uint transferAmount = value*(100 - marketingTaxPercent - founderTaxPercent)/100;
        balances[to] += transferAmount;

        //subtract full value from sender except reward tokens which aren't accounted for in the balances mapping
        balances[msg.sender] -= (value - rewardTokens);
        emit Transfer(msg.sender, to, transferAmount);

        // calculate marketing tax
        uint marketingTaxAmount = value*(marketingTaxPercent)/100;

        //transfer 5% to marketing
        balances[marketingAccount] += marketingTaxAmount;
        emit Transfer(msg.sender, marketingAccount, marketingTaxAmount);

        // calculate founder tax
        uint founderTaxAmount = value*(founderTaxPercent)/100;

        //tranfer 5% to founder
        balances[founderAccount] += founderTaxAmount;
        emit Transfer(msg.sender, founderAccount, founderTaxAmount);

        // set the time the the receiver gets their first token
        // (if they already have a tokenHolderTimestamp then they should keep it and we shouldn't overwrite it)
        if(tokenHolderTimestamp[to] == 0) {
            // save time when receiver recieves first token
            tokenHolderTimestamp[to] = block.timestamp;
        }

        // if sender sends all their tokens they should reset their holding timestamp
        if(balanceOf(msg.sender) == 0) {
            tokenHolderTimestamp[msg.sender] = 0;
        }

        return true;
    }

    function transferFrom(address from, address to, uint value) public returns(bool) {
        // check sending account has enough 
        require(balanceOf(from) >= value, 'balance too low');

        // check allowance is enough
        require(allowance[from][msg.sender] >= value, 'allowance too low');

        // calculate bonus allocation so we can prevent it from being deducted from balances mapping
        uint rewardTokens;
        if (tokenHolderTimestamp[from] != 0) {
            //calc amount of months tokens held
            uint periodsElapsed = (block.timestamp - tokenHolderTimestamp[from])/(rewardPeriod * 1 days);
            //calc amount of reward tokens
            rewardTokens = rewardPerPeriod * periodsElapsed;

        //if token holder has no timestamp, return the raw balance
        } else if (tokenHolderTimestamp[from] == 0) {
            rewardTokens = 0;
        }

        // subtract value from allowance
        allowance[from][msg.sender] -= value;

        // calculate transfer amount which is equal to value minus tax
        uint transferAmount = value*(100 - marketingTaxPercent - founderTaxPercent)/100;

        // transfer tokens to new account
        balances[to] += transferAmount;

        // subtract full amount from sender (not including rewards tokens which are not accounted for in balances mapping)
        balances[from] -= value;
        emit Transfer(from, to, transferAmount);

        // calculate marketing tax
        uint marketingTaxAmount = value*(marketingTaxPercent)/100;

        //transfer tax to marketing account
        balances[marketingAccount] += marketingTaxAmount;
        emit Transfer(from, marketingAccount, marketingTaxAmount);

        // calculate founder tax
        uint founderTaxAmount = value*(founderTaxPercent)/100;

        //tranfer 5% to founder
        balances[founderAccount] += founderTaxAmount;
        emit Transfer(from, founderAccount, founderTaxAmount);

        // set the time the the receiver gets their first token
        // (if they already have a tokenHolderTimestamp then they should keep it and we shouldn't overwrite it)
        if(tokenHolderTimestamp[to] == 0) {
            // save time when receiver recieves first token
            tokenHolderTimestamp[to] = block.timestamp;
        }

        // if sender sends all their tokens they should reset their holding timestamp
        if(balanceOf(from) == 0) {
            tokenHolderTimestamp[from] = 0;
        }

        return true;
    }

    // function to marketing alter tax
    // max tax is 50% as that would mean 100% of transfers go to founder and marketing (50% each)
    // onlyOwner added as check to ensure only the owner can call this function
    function setMarketingTax(uint newMarketingTax) public onlyOwner {
        require(newMarketingTax <= 50);
        marketingTaxPercent = newMarketingTax;
    }

    // function to founder alter tax
    // max tax is 50% as that would mean 100% of transfers go to founder and marketing (50% each)
    // onlyOwner added as check to ensure only the owner can call this function
    function setFounderTax(uint newFounderTax) public onlyOwner {
        require(newFounderTax <= 50);
        founderTaxPercent = newFounderTax;
    }

    // added function to alter reward
    // onlyOwner added as check to ensure only the owner can call this function
    function setReward(uint newReward) public onlyOwner {
        rewardPerPeriod = newReward;
    }

    // function to change contract owner account
    // onlyOwner added as check to ensure only the owner can call this function
    function changeOwner(address newOwner) public onlyOwner {
        contractOwner = newOwner;
    }

    // function to change contract founder account
    // onlyOwner added as check to ensure only the owner can call this function
    function changeFounderAccount(address newFounderAccount) public onlyOwner {
        founderAccount = newFounderAccount;
    }

    // function to change contract marketing account
    // onlyOwner added as check to ensure only the owner can call this function
    function changeMarketingAccount(address newMarketingAccount) public onlyOwner {
        marketingAccount = newMarketingAccount;
    }

    function toggleRewards(bool rewardState) public returns (bool) {
        rewardsEnabled = rewardState;
        return true;
    }

    function approve(address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
}