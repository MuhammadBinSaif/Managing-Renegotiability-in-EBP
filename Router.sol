// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Proxy.sol"; // Import the actual contract code
// Interface for the Proxy
interface IProxy {
    function executeMigration(bytes32 _instanceId, address _newLogicAddress, bytes calldata _data) external;
}

contract Router {
    address public admin;
    IProxy public proxy;

    // Governance Storage
    struct InstanceInfo {
        address currentLogicAddress; // Current logic contract for this instance
        address governor; // The multi-sig or address that can approve upgrades
    }
    // mapping for storing the version of smart contract against the instance
    // this is the actual mapping which is reponsible for instance level versioning
    mapping(bytes32 => InstanceInfo) public instanceInfo;

    // mapping for storing the upgrade proposal
    // new updated smart contract address with bug fixes or upgraded functionality
    // This temporarily stores which version an instance might upgrade to, before the governor confirms it
    mapping(bytes32 => address) public upgradeProposals;

    // Version Control Storage
    // Mapping of all approved logic contract versions
    mapping(string => address) public availableVersions;

    // Scenario when there is mandatory bug fix
    // maps the buggy logic contract to the address of its fixed replacement
    mapping(address => address) public deprecatedVersion;

    // Counter for generating unique instance IDs internally
    uint256 public nextInstanceNonce;

    // Events
    event InstanceCreated(bytes32 indexed instanceId, address indexed governor, address logicAddress);
    event InstanceUpgraded(bytes32 indexed instanceId, address indexed newLogicAddress);
    event VersionDeprecated(address indexed buggy, address indexed replacement);

    constructor() {
        admin = msg.sender;
        Proxy deployedProxy = new Proxy(address(this));
        // Store the address of the newly created Proxy
        proxy = IProxy(address(deployedProxy));
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    // Version Management
    // Allows the admin to add a new deployed logic contract address to the availableVersions mapping, associating it with a name.
    function registerNewVersion(string calldata _versionName, address _logicAddress) external onlyAdmin {
        availableVersions[_versionName] = _logicAddress;
    }

    // For Scenario when a buggy logic contract and provides a safe replacement.
    function deprecateVersion(address _buggyLogic, address _replacementLogic) external onlyAdmin {
        deprecatedVersion[_buggyLogic] = _replacementLogic;
        emit VersionDeprecated(_buggyLogic, _replacementLogic);
    }

    // Instance Management
    // Function to create a new instance with a specific version assigned.
    // This function now generates the instance ID internally using a counter.
    function createNewInstance(
        string calldata _startVersion,
        address _governor
    )
        external
        onlyAdmin
        returns (bytes32 newInstanceId) // It returns the generated ID
    {
        require(_governor != address(0), "Invalid governor");
        address logicAddress = availableVersions[_startVersion];
        require(logicAddress != address(0), "Version not found");

        // Generate the new ID from the counter
        uint256 currentNonce = nextInstanceNonce;
        newInstanceId = bytes32(currentNonce); // Cast the counter value to bytes32

        // Check to prevent accidental ID collision 
        require(instanceInfo[newInstanceId].governor == address(0), "ID collision");

        // Increment the nonce for the next instance
        nextInstanceNonce++;

        // Store the instance info using the internally generated ID
        instanceInfo[newInstanceId] = InstanceInfo({
            currentLogicAddress: logicAddress,
            governor: _governor
        });

        // Emit the event with the generated ID
        emit InstanceCreated(newInstanceId, _governor, logicAddress);
    }

    // new upgrade proposes by the admin to upgrade a specific instance to new version
    // it is just a proposal so we are storing the information in proposal mapping
    function proposeUpgrade(bytes32 _instanceId, string calldata _newVersionName) external {
        address newLogicAddress = availableVersions[_newVersionName];
        require(newLogicAddress != address(0), "New version not found");
        upgradeProposals[_instanceId] = newLogicAddress;
    }

    // function which after confirmation upgrades the instance to new version
    function confirmUpgrade(bytes32 _instanceId, bytes calldata _upgradeData) external {
        // a reference pointer to the instance data in storage
        InstanceInfo storage instance = instanceInfo[_instanceId];
        require(msg.sender == instance.governor, "Not authorized governor");

        address newLogicAddress = upgradeProposals[_instanceId];
        require(newLogicAddress != address(0), "No proposal found");

        // Scenario when execute state migration if data is provided
        if (_upgradeData.length > 0) {
            proxy.executeMigration(_instanceId, newLogicAddress, _upgradeData);
        }

        // Complete the upgrade
        instance.currentLogicAddress = newLogicAddress;
        delete upgradeProposals[_instanceId];
        emit InstanceUpgraded(_instanceId, newLogicAddress);
    }

    // lookup function Called by Proxy fallback
    function getLogicForInstance(bytes32 _instanceId) external view returns (address) {
        address logic = instanceInfo[_instanceId].currentLogicAddress;
        if (logic == address(0)) {
            return address(0); // Instance doesn't exist
        }

        // Scenario when mandatory bug fixes replaces the old version to new version
        address replacementLogic = deprecatedVersion[logic];
        if (replacementLogic != address(0)) {
            return replacementLogic; // Force route to fixed version
        }

        return logic; // Return the standard version
    }
}