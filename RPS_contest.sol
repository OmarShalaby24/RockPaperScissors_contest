// SPDX-License-Identifier: GPL-3.0
//pragma solidity ^0.8.4;
pragma solidity >=0.7.0 <0.9.0;

contract RPS_Game{
    //variables
    address contractCreator;
    uint public reward;
    uint public deposit;
    uint committingEnd;
    uint revealingEnd;
    uint withdrawTime;
    bool ended;
    bool public tie;

    address public winner;
    address payable player1_addr;
    address payable player2_addr;

    mapping(address => bytes32) public commitments;
    mapping(address => uint) public decisions;
    mapping(address => bool) public revealed;
    mapping(address => uint) public rewards;
    mapping(address => uint) public indemnity;

    //errors
    error TooEarly(uint time);
    error TooLate(uint time);
    error InvalidValue(uint v, uint t);
    //error incorrectData(bytes32 realCommit, bytes32 fakeCommit);
    error GameEndAlreadycalled();

    //events
    event GameEnded(address p1, uint p1Reward, address p2, uint p2Reward);

    //modifiers
    modifier verifyAddress(address caller){
        require(caller == player1_addr || caller == player2_addr,
        "You are not allowed to participate"
        );
        _;
    }
    modifier verifyManager(){
        require(msg.sender == contractCreator , " You are not the manager");
        _;
    }
    modifier onlyBefore(uint time){
        if (block.timestamp >= time) revert TooLate(time);
        _;                                                                                  //no idea
    }
    modifier onlyAfter(uint time){
        if (block.timestamp <= time) revert TooEarly(time);
        _;
    }
    modifier checkReward(){
        require (msg.value == 2*reward , "Need to pay 2 x reward! (reward and deposit)");
        _;
    }
    /*modifier GameStarted(){
        require (deposit !=0, "The game hasn't started yet")
        _;
    }*/

    //functions
    constructor(
        uint reward_Value,
        address payable palyer1,
        address payable palyer2
    ){
        contractCreator = msg.sender;
        player1_addr = palyer1;
        player2_addr = palyer2;
        reward = reward_Value * (1 ether);
    }

    function Start_Game(uint commit_Time, uint reveal_Time, uint Withdraw_Time)
        external
        payable
    {
        if(msg.sender == contractCreator && msg.value == 2*reward){
            committingEnd = block.timestamp + commit_Time;
            revealingEnd = committingEnd + reveal_Time;
            withdrawTime = revealingEnd + Withdraw_Time;
            deposit = reward;
            indemnity[player1_addr] = reward/2 + deposit/2;
            indemnity[player2_addr] = reward/2 + deposit/2;
        }
        else
            revert InvalidValue(msg.value, 2*reward);           //or not the manager called the function
    }

    //to be easy
    //automatically inserting the address in the haching func. (so if the participant will make it manually he must use his address, decision and a nonce)
    //removable
    function Generate_Commitmint(string calldata decision, string calldata nonce)
    external
    view
    returns (bytes32)
    {
        return keccak256(abi.encodePacked(msg.sender,decision,nonce));
    }

    /*
    not payabel as if a player didn't reveal the other player will win (fair for both players)
    if both didn't reveal so it's a tie     (protect the manager's money)
    */
    function MakeCommitment(bytes32 commit)                     
    external
    verifyAddress(msg.sender)
    onlyBefore(committingEnd)
    //GameStarted()
    {
        commitments[msg.sender] = commit;           // is the participant is allowed to change his decision? yes
    }

    function Reveal(string calldata decision, string calldata nonce)
    external
    verifyAddress(msg.sender)
    onlyBefore(revealingEnd)
    onlyAfter(committingEnd)
    {
        bytes32 commitmentToCheck = commitments[msg.sender];
        if(commitmentToCheck == keccak256(abi.encodePacked(msg.sender,decision,nonce))){
            if(keccak256(abi.encodePacked(decision)) == keccak256(abi.encodePacked("rock"))){
                decisions[msg.sender] = 1;
            }
            else if(keccak256(abi.encodePacked(decision)) == keccak256(abi.encodePacked("paper"))){
                decisions[msg.sender] = 2;
            }
            else if(keccak256(abi.encodePacked(decision)) == keccak256(abi.encodePacked("scissors"))){
                decisions[msg.sender] = 3;
            }
            revealed[msg.sender] = true;

            //decisions[msg.sender] = decision;
        }
        /*if(revealed[player1_addr] && revealed[player2_addr]){
            fight(decisions[player1_addr], decisions[player2_addr]);
        }*/
    }

    //in case the manager refused to end the game
    function withdraw()
    external
    onlyAfter(withdrawTime)
    verifyAddress(msg.sender)
    {
        uint = amount;
        if(ended) revert GameEndAlreadycalled();
        else
        {
            amount = indemnity[msg.sender];
            indemnity[msg.sender] = 0;
            deposit = deposit - indemnity[msg.sender];
            payable(msg.sender).transfer(indemnity[msg.sender]);
        }
    }

    function GameEnd()
    external
    onlyAfter(revealingEnd)
    onlyBefore(withdrawTime)
    verifyManager()
    {
        uint = amount;   

        if(ended) revert GameEndAlreadycalled();
        ended = true;
        

        if(!revealed[player1_addr] && revealed[player2_addr]){
            Player2_wins();
        }
        else if(revealed[player1_addr] && !revealed[player2_addr]){
            Player1_wins();
        }
        else if(!revealed[player1_addr] && !revealed[player2_addr]){
            rewards[player1_addr] = 0;
            rewards[player2_addr] = 0;
            amount = reward;
            reward = 0;
            payable(contractCreator).transfer(amount);
        }
        fight(decisions[player1_addr], decisions[player2_addr]);
        amount = rewards[player1_addr];
        rewards[player1_addr] = 0;
        player1_addr.transfer(rewards[amount]);
        amount = rewards[player2_addr];
        rewards[player2_addr] = 0;
        player2_addr.transfer(rewards[amount]);
        
        emit GameEnded(player1_addr, rewards[player1_addr], player2_addr, rewards[player2_addr]);
        
        indemnity[player1_addr] = 0;
        indemnity[player2_addr] = 0;
        amount = deposit;
        deposit = 0;
        payable(contractCreator).transfer(amount);

    }

    function fight(uint d1, uint d2)
    internal
    returns (uint wnr)                                           //0 tie     1 p1        2 p2
    {
        if(d1 == d2){
            tie = true;
            winner = address(0);
            rewards[player1_addr] = reward/2;
            rewards[player2_addr] = reward/2;
            reward = 0;
            return 0;
        }
        if (d1 == 1){
            if (d2 == 2){
                //player 2 wins
                Player2_wins();
                return 2;
            }
            else if (d2 == 3){                                  //          rock        scissors
                //player 1 wins
                Player1_wins();
                return 1;
            }
        }
        else if (d1 == 2){
            if (d2 == 3){                                       //          paper       scissors
                //player 2 wins
                Player2_wins();
                return 2;
            }
            else if (d2 == 1){                                  //          paper       rock
                //player 1 wins
                Player1_wins();
                return 1;
            }
        }
        else if (d1 == 3){
            if (d2 == 1){                                       //          scissors    rock
                //player 2 wins
                Player2_wins();
                return 2;
            }
            else if (d2 == 2){                                  //          scissors    paper
                //player 1 wins
                Player1_wins();
                return 1;
            }
        }
        

    }

    function Player1_wins()
    internal
    {
        tie = false;
        winner = player1_addr;
        rewards[player1_addr] = reward;
        rewards[player2_addr] = 0;
        reward = 0;

    }
    function Player2_wins()
    internal
    {
        tie = false;
        winner = player2_addr;
        rewards[player1_addr] = 0;
        rewards[player2_addr] = reward;
        reward = 0;

    }


}
