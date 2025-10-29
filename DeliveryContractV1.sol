// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SharedStorage.sol";

/**
 * @title DeliveryContract
 * @dev V1: Simple Pay-on-Delivery.
 * The Courier confirms delivery, and funds are released automatically.
 * BUG: 'confirmDelivery' is not access-controlled.
 */
contract DeliveryContractV1 is SharedStorage {

    // A helper to release funds
    function _releaseFunds(ProcessState storage order) internal {
        // release funds to seller
        payable(order.seller).transfer(order.itemValue);
        // release funds to courier
        payable(order.courier).transfer(order.shippingFee);
        // change order status
        order.status = OrderStatus.COMPLETED;
    }

    // Called by the Buyer to create and fund the order
    function createOrder(
        bytes32 _orderId,
        address _seller,
        address _courier,
        uint256 _shippingFee
    ) external payable {
        ProcessState storage order = processStates[_orderId];
        require(order.buyer == address(0), "Order already exists");
        
        order.buyer = msg.sender;
        order.seller = _seller;
        order.courier = _courier;
        order.shippingFee = _shippingFee;
        order.itemValue = msg.value - _shippingFee; // Rest is item value
        order.status = OrderStatus.PENDING;
        
        require(order.itemValue > 0, "Insufficient payment for shipping");
    }

    // Called by the Seller
    function shipOrder(bytes32 _orderId) external {
        ProcessState storage order = processStates[_orderId];
        require(msg.sender == order.seller, "Seller only");
        require(order.status == OrderStatus.PENDING, "Not pending");
        order.status = OrderStatus.SHIPPED;
    }

    // *** THE BUGGY FUNCTION ***
    // Called by the Courier (but not enforced!)
    function confirmDelivery(bytes32 _orderId) external {
        ProcessState storage order = processStates[_orderId];
        require(order.status == OrderStatus.SHIPPED, "Not shipped");
        
        // V1 Logic: Auto-release funds on delivery
        _releaseFunds(order);
    }
}