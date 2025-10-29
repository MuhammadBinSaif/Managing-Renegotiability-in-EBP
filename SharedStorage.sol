// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Defines the shared storage layout for the Pay-on-Delivery process.
 */
abstract contract SharedStorage {
    // Status 
    enum OrderStatus { PENDING, SHIPPED, DELIVERED, COMPLETED, DISPUTED }

    struct ProcessState {
        address buyer;
        address seller;
        address courier;
        uint256 itemValue;
        uint256 shippingFee;
        OrderStatus status;
        // --- V3 Variable ---
        // V1 and V2 logic will ignore this storage slot.
        bool buyerConfirmed; 
    }

    /**
     * This mapping physically lives in the Proxy storage.
     * The key is the 'orderId' (our instanceId).
     */
    mapping(bytes32 => ProcessState) public processStates;
}