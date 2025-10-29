// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./sharedstorage.sol";

// Interface for the Router
interface IRouter {
    function getLogicForInstance(bytes32 _instanceId) external view returns (address);
}

contract Proxy is SharedStorage {
    
    address public immutable routerContractAddress;

    constructor(address _routerAddress) {
        require(_routerAddress != address(0), "Invalid router");
        routerContractAddress = _routerAddress;
    }

    fallback() external payable {
        // Assign msg.data to a local variable 
        bytes memory data = msg.data; 

        bytes32 instanceId;
        if (data.length >= 36) {
            assembly {
                // 'data' points to the length (0x20 bytes).
                // The actual data starts at data + 0x20.
                // We skip 4 bytes for the selector. Total offset = 0x24.
                
                instanceId := mload(add(data, 0x24))
            }
        } else {
            revert("Invalid call data");
        }

        // 2. Ask the router for the logic address
        address logicAddress = IRouter(routerContractAddress).getLogicForInstance(instanceId);
        require(logicAddress != address(0), "Instance not found or inactive");

        // 3. Forward the call using DELEGATECALL

        (bool success, bytes memory result) = logicAddress.delegatecall(data);

        // 4. Return the result or popup the error
        if (success) {
            assembly {
                return(add(result, 0x20), mload(result))
            }
        } else {
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }
    }
    
    receive() external payable {}

    // function for data migration called by the router only after confirmation of the governer  
    function executeMigration(bytes32 _instanceId, address _newLogicAddress, bytes calldata _data) external {
        require(msg.sender == routerContractAddress, "Router only");
        
        (bool success,) = _newLogicAddress.delegatecall(
            abi.encodeWithSignature("performStateMigration(bytes32,bytes)", _instanceId, _data)
        );
        require(success, "Migration failed");
    }
}