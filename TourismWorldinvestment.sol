// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bytes4 selector = bytes4(keccak256("transferFrom(address,address,uint256)"));
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }
}

contract TourismWorldInvestment {
    string public name = "Tourism World Investment";
    string public symbol = "TWI";
    uint8 public decimals = 6;
    string public constant PROJECT_OWNER_GROUP = "100JORDAN";

    address public owner;
    address public pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferProposed(address indexed currentOwner, address indexed pendingOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function proposeOwnershipTransfer(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        pendingOwner = _newOwner;
        emit OwnershipTransferProposed(owner, _newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Caller is not the pending owner");
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    function renounceOwnership() external onlyOwner {
        address oldOwner = owner;
        owner = address(0);
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    bool public paused;
    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    address public immutable usdtAddress;
    IERC20 public immutable usdtToken;

    uint256 public constant TOTAL_CAP = 20_000_000 * 10**6;
    uint256 public constant PHASE_CAP = 5_000_000 * 10**6;
    uint256 public constant MAX_INVEST_WHOLE = 5_000_000;
    uint256 public constant PAID_CAPITAL_AND_ASSETS = 3_000_000 * 10**6;

    uint256 public currentPhase = 1;
    uint256 public raisedInCurrentPhase;
    uint256 public totalRaisedGlobal;

    mapping(uint256 => uint256) public phaseRaisedHistory;
    mapping(address => uint256) public totalInvestmentOf;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Invested(address indexed investor, uint256 indexed phase, uint256 usdtAmount, uint256 twiMinted);
    event PhaseAdvanced(uint256 indexed completedPhase, uint256 indexed nextPhase, uint256 amountRaisedInPhase);
    event ProjectCompleted(uint256 totalGlobalRaised);
    event FundsWithdrawn(address indexed beneficiary, uint256 amount);
    event TokensRescued(address indexed token, address indexed beneficiary, uint256 amount);

    constructor(address _usdtAddress) {
        require(_usdtAddress != address(0), "USDT address cannot be zero");
        owner = msg.sender;
        usdtAddress = _usdtAddress;
        usdtToken = IERC20(_usdtAddress);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function invest(uint256 wholeAmountInUSDT) external whenNotPaused {
        require(currentPhase <= 4, "All 4 investment phases are completed");
        require(wholeAmountInUSDT > 0, "Investment amount must be greater than 0");
        require(wholeAmountInUSDT <= MAX_INVEST_WHOLE, "Amount exceeds max per-investment limit");

        uint256 amountInUSDT = wholeAmountInUSDT * 10**6;

        require(raisedInCurrentPhase + amountInUSDT <= PHASE_CAP, "Exceeds current phase cap of 5M USDT");
        require(totalRaisedGlobal + amountInUSDT <= TOTAL_CAP, "Exceeds total project cap of 20M USDT");

        raisedInCurrentPhase += amountInUSDT;
        totalRaisedGlobal += amountInUSDT;
        totalInvestmentOf[msg.sender] += amountInUSDT;
        _mint(msg.sender, amountInUSDT);

        emit Invested(msg.sender, currentPhase, amountInUSDT, amountInUSDT);

        if (raisedInCurrentPhase == PHASE_CAP) {
            uint256 finishedPhase = currentPhase;
            uint256 amountRaised = raisedInCurrentPhase;
            phaseRaisedHistory[finishedPhase] = amountRaised;
            if (currentPhase < 4) {
                currentPhase++;
                raisedInCurrentPhase = 0;
                emit PhaseAdvanced(finishedPhase, currentPhase, amountRaised);
            } else {
                emit ProjectCompleted(totalRaisedGlobal);
            }
        }

        SafeERC20.safeTransferFrom(usdtToken, msg.sender, address(this), amountInUSDT);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[msg.sender] >= amount, "Transfer amount exceeds balance");

        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "Approve to the zero address");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Transfer amount exceeds balance");
        require(_allowances[sender][msg.sender] >= amount, "Transfer amount exceeds allowance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function advancePhaseManually() external onlyOwner {
        require(currentPhase < 4, "Already at final phase");
        uint256 finishedPhase = currentPhase;
        uint256 amountRaised = raisedInCurrentPhase;
        phaseRaisedHistory[finishedPhase] = amountRaised;
        currentPhase++;
        raisedInCurrentPhase = 0;
        emit PhaseAdvanced(finishedPhase, currentPhase, amountRaised);
    }

    function withdrawFunds(address beneficiary) external onlyOwner {
        require(beneficiary != address(0), "Cannot withdraw to zero address");
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No funds available");

        emit FundsWithdrawn(beneficiary, balance);
        SafeERC20.safeTransfer(usdtToken, beneficiary, balance);
    }

    function rescueToken(address token, address beneficiary) external onlyOwner {
        require(token != address(0), "Token cannot be zero address");
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(token != usdtAddress, "Cannot rescue USDT through this function");

        IERC20 rescueTokenContract = IERC20(token);
        uint256 balance = rescueTokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to rescue");

        SafeERC20.safeTransfer(rescueTokenContract, beneficiary, balance);
        emit TokensRescued(token, beneficiary, balance);
    }
}
