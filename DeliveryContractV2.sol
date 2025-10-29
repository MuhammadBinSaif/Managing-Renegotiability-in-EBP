// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SharedStorage.sol";

/**
 * @title DeliveryContractV2
 * V2: Bug Fix.
 * Patches the security flaw in 'confirmDelivery'.
 */
contract DeliveryContractV2 is SharedStorage {

    // A helper to release funds
    function _releaseFunds(ProcessState storage order) internal {
        // release funds to seller
        payable(order.seller).transfer(order.itemValue);
        // release funds to courier
        payable(order.courier).transfer(order.shippingFee);
        // change order status to completed after shipper confirmation
        order.status = OrderStatus.COMPLETED;
    }

    // createOrder (unchanged)
    function createOrder(
        bytes32 _orderId,
        address _seller,
        address _courier,
        uint256 _shippingFee
    ) external payable {
       // Same code as V1
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
        // Same code as V1
        ProcessState storage order = processStates[_orderId];
        require(msg.sender == order.seller, "Seller only");
        require(order.status == OrderStatus.PENDING, "Not pending");
        order.status = OrderStatus.SHIPPED;
    }

    // The fixed function with verification of courier
    function confirmDelivery(bytes32 _orderId) external {
        ProcessState storage order = processStates[_orderId];
        
        // The fix: now only courier can change the status to shipped
        require(msg.sender == order.courier, "Courier only");
        require(order.status == OrderStatus.SHIPPED, "Not shipped");
        
        _releaseFunds(order);
    }
}