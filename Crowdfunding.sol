//SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0 <0.9.0;

contract CrowdFunding {
    mapping(address => uint) public contributors;
    address public admin;
    uint public noOfContributors;
    uint public minimumContribution; 
    uint public deadline; //timestamp
    uint public goal;
    uint public raisedAmount;

    struct Request {
        string description;
        address payable recipient;
        uint value;
        bool compeleted;
        uint noOfVoters;
        mapping(address => bool) voters;
    }

    mapping(uint => Request) public requests; 
    //use mapping to store collection of requests cause arrays can't have
    //mapping as a member type
    uint public numRequests; //keep track of the index cause mapping doesn't 
                             //increment indexes automatically like arrays
    constructor(uint _goal, uint _deadline) {
        goal = _goal;
        deadline = block.timestamp + _deadline;
        minimumContribution = 100 wei;
        admin = msg.sender;
    }

    event ContributeEvent(address _sender, uint _value);
    event CreateRequestEvent(string _description, address _recipient, uint _value);
    event MakePaymentEvent(address _recipient, uint _value);

    function contribute() public payable {
        require (block.timestamp < deadline, "Deadline has passed!");
        require(msg.value >= minimumContribution, "Minimum contribution not met");
        
        //Adding the number of contributors, but contributors can contribute many times
        if(contributors[msg.sender] == 0) {
            noOfContributors++;
        }
        //Updating the amount of contribution by this contributor
        contributors[msg.sender] += msg.value;
        //updating the amount of raised contribution
        raisedAmount += msg.value;

        emit ContributeEvent(msg.sender, msg.value);
    }

    receive() payable external {
        contribute();
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function getRefund() public {
        //can only request for refund after the campaign ended & the amount raised
        //is less than the goal
        require(block.timestamp > deadline && raisedAmount < goal);
        
        //only a contributor can request a refund
        require(contributors[msg.sender] > 0);

        payable(msg.sender).transfer(contributors[msg.sender]);

        //resetting the contribution value
        contributors[msg.sender] = 0;

    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function!");
        _;
    }

    function createRequest(string memory _description, address payable _recipient, uint _value) public onlyAdmin {
        Request storage newRequest = requests[numRequests];
        //need to declare storage cause the struct contains a nested mapping
        numRequests++;

        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.compeleted = false;
        newRequest.noOfVoters = 0;

        emit CreateRequestEvent(_description, _recipient, _value);
    }

    //donators voting for which request the campaign creator to use the donation 
    function voteRequest(uint _requestNo) public {
        //make sure only contibutors can vote
        require(contributors[msg.sender] > 0, "You must be a conrtibutor to vote!");
        Request storage thisRequest = requests[_requestNo];

        //The current user hasn't voted for the request yet
        require(thisRequest.voters[msg.sender] == false, "You have already voted");
        thisRequest.voters[msg.sender] = true;
        thisRequest.noOfVoters++;
    }

//The function can be called only after the admin has created a spending request &
//the contributos aleady made their votes
    function makePayment(uint _requestNo) public onlyAdmin {
        //make payment only after the goal is reached
        require(raisedAmount >= goal);
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.compeleted == false, "The request has been completed!");

        //PAYMENT only allowed after at least 50% of contributors voted
        require(thisRequest.noOfVoters > noOfContributors / 2); //50% voted for this request

        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.compeleted = true;

        emit MakePaymentEvent(thisRequest.recipient, thisRequest.value);

    }

}