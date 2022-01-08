// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

/**
 * DAO contract:
 * 1. Collects investors money (ether) & allocate shares
 * 2. Keep track of investor contributions with shares (increment shares and available amount accordingly)
 * 3. Allow investors to transfer shares
 * 4. allow investment proposals to be created and voted
 * 5. execute successful investment proposals (i.e send money)
 */

contract DAO {
    
    struct Proposal {
        uint256 ID;
        string name;
        uint256 amount;
        address payable recipient;
        uint256 votes;
        uint256 end;
        bool executed;
    }
    
    mapping(address => bool) public investors;
    mapping(address => uint256) public shares;
    mapping(address => mapping(uint256 => bool)) public votes;
    mapping(uint256 => Proposal) public proposals;
    uint256 public totalShares;
    uint256 public availableFunds;
    uint256 public contributionEnd;
    uint256 public nextProposalID;
    uint256 public votingDuration;
    uint256 public quorum;
    address private admin;
    
    constructor(
        uint256 contributionTime,
        uint256 _votingDuration,
        uint256 _quorum
        ) {
        require(_quorum > 0 && _quorum < 100, 'invalid quorum');
        contributionEnd = block.timestamp + contributionTime;
        votingDuration = _votingDuration;
        quorum = _quorum;
        admin = msg.sender;
    }
    
    function fund() payable external {
        require(block.timestamp < contributionEnd, 'only available during funding period');
        investors[msg.sender] = true;
        shares[msg.sender] += msg.value;
        availableFunds += msg.value;
    }
    
    function redeemShare(uint256 amount) external {
        require(shares[msg.sender] >= amount, 'insufficient share balance');
        require(availableFunds >= amount, 'no liquidity');
        shares[msg.sender] -= amount;
        availableFunds -= amount;
        payable(msg.sender).transfer(amount);
    }
    
    function transferShare(uint256 amount, address to) external {
        require(shares[msg.sender] >= amount, 'insufficient share balance');
        shares[msg.sender] -= amount;
        shares[to] += amount;
        investors[to] = true;
    }
    
    function createProposal(
        string memory name,
        uint256 amount,
        address payable recipient
        ) public onlyInvestors() {
            require(availableFunds >= amount, 'Invalid amount');
            proposals[nextProposalID] = Proposal(
                nextProposalID,
                name,
                amount,
                recipient,
                0,
                block.timestamp + votingDuration,
                false
                );
            availableFunds -= amount;
            nextProposalID++; 
        }
        
    function vote(uint256 proposalID) external onlyInvestors() {
        Proposal storage proposal = proposals[proposalID];
        require(votes[msg.sender][proposalID] == false, 'One vote only');
        require(block.timestamp < proposal.end, 'Strictly no late votes');
        votes[msg.sender][proposalID] = true;
        proposal.votes += shares[msg.sender];
    }
    
    function executeProposal(uint256 proposalID) external onlyAdmin() {
        Proposal storage proposal = proposals[proposalID];
        require(block.timestamp >= proposal.end, 'Cannot execute before end date');
        require(proposal.executed == false, 'already executed');
        require((proposal.votes / totalShares) * 100 >= quorum, 'insufficient votes');
        _transferEther(proposal.amount, proposal.recipient);
    }
    
    function emergencyWithdrawal(uint256 amount, address payable to) external onlyAdmin() {
        _transferEther(amount, to);
    }
    
    receive() payable external {
        availableFunds += msg.value;
    }
    
    function _transferEther(uint256 amount, address payable to) internal {
        require(amount <= availableFunds, 'insufficient funds');
        availableFunds -= amount;
        to.transfer(amount);
    }
    
    modifier onlyInvestors() {
        require(investors[msg.sender] == true, 'only investors');
        _;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, 'only admin may execute this function');
        _;
    }
    
}