// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SharedStorage.sol";

/**
 * @title DeliveryContractV3
 * @dev V3: New "Buyer Confirmation" Feature.
 * Solves contractual incompleteness. Courier delivery is now separate
 * from Buyer confirmation, which releases the funds.
 */
contract DeliveryContractV3 is SharedStorage {

    // Helper function (unchanged)
    function _releaseFunds(ProcessState storage order) internal {
        payable(order.seller).transfer(order.itemValue);
        payable(order.courier).transfer(order.shippingFee);
        order.status = OrderStatus.COMPLETED;
    }
    
    // createOrder (unchanged)
    function createOrder(
        bytes32 _orderId,
        address _seller,
        address _courier,
        uint256 _shippingFee
    ) external payable {
       // Same code as V1/V2
       ProcessState storage order = processStates[_orderId];
       require(order.buyer == address(0), "Order already exists");
       order.buyer = msg.sender;
       order.seller = _seller;
       order.courier = _courier;
       order.shippingFee = _shippingFee;
       order.itemValue = msg.value - _shippingFee;
       order.status = OrderStatus.PENDING;
       require(order.itemValue > 0, "Insufficient payment for shipping");
    }

    // shipOrder (unchanged)
    function shipOrder(bytes32 _orderId) external {
        // ... (Same code as V1/V2)
        ProcessState storage order = processStates[_orderId];
        require(msg.sender == order.seller, "Seller only");
        require(order.status == OrderStatus.PENDING, "Not pending");
        order.status = OrderStatus.SHIPPED;
    }

    // MODIFIED FUNCTION (V3)
    // 'confirmDelivery' NO LONGER releases funds. It just updates state.
    function confirmDelivery(bytes32 _orderId) external {
        ProcessState storage order = processStates[_orderId];
        require(msg.sender == order.courier, "Courier only");
        require(order.status == OrderStatus.SHIPPED, "Not shipped");
        
        order.status = OrderStatus.DELIVERED;
    }

    // NEW FUNCTION (V3)
    // This new function is added to release the funds, only by the buyer.
    function confirmReceipt(bytes32 _orderId) external {
        ProcessState storage order = processStates[_orderId];
        require(msg.sender == order.buyer, "Buyer only");
        require(order.status == OrderStatus.DELIVERED, "Not delivered yet");
        
        // This writes to the new V3 storage slot
        order.buyerConfirmed = true; 
        
        // Now release funds
        _releaseFunds(order);
    }

    // New function to get the order status
    function getOrderStatus(bytes32 _orderId) external view returns (OrderStatus) {
        // V3 can now read the status using the enum type directly
        return processStates[_orderId].status;
    }
    
    // *** NEW MIGRATION FUNCTION (V3) ***
    // This is called by the Router (via the Proxy) during an upgrade.
    function performStateMigration(bytes32 _orderId, bytes calldata _data) external {
        // Decode the default value for 'buyerConfirmed'
        bool defaultConfirmation = abi.decode(_data, (bool));
        
        // This writes to the new V3 storage slot for the migrating instance
        processStates[_orderId].buyerConfirmed = defaultConfirmation;
    }
}