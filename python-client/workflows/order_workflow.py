"""
Order processing workflow for Temporal demo.
Orchestrates the order fulfillment process.
"""

from datetime import timedelta
from temporalio import workflow
from temporalio.common import RetryPolicy

# Import activities
with workflow.unsafe.imports_passed_through():
    from activities.order_activities import (
        validate_order,
        process_payment,
        send_confirmation,
    )


@workflow.defn
class OrderWorkflow:
    """
    Workflow that processes an order from validation to confirmation.

    This demonstrates:
    - Sequential activity execution
    - Retry policies
    - Workflow state management
    - Durable execution
    """

    @workflow.run
    async def run(self, order_id: str, amount: float, email: str) -> str:
        """
        Execute the order processing workflow.

        Args:
            order_id: Unique order identifier
            amount: Order amount in dollars
            email: Customer email for confirmation

        Returns:
            Final workflow status message
        """
        workflow.logger.info(f"Starting order workflow for: {order_id}")

        # Step 1: Validate the order
        validation_result = await workflow.execute_activity(
            validate_order,
            order_id,
            start_to_close_timeout=timedelta(seconds=30),
            retry_policy=RetryPolicy(
                maximum_attempts=3,
                initial_interval=timedelta(seconds=1),
                maximum_interval=timedelta(seconds=10),
            ),
        )
        workflow.logger.info(f"Validation: {validation_result}")

        # Step 2: Process payment
        payment_result = await workflow.execute_activity(
            process_payment,
            args=[order_id, amount],
            start_to_close_timeout=timedelta(seconds=60),
            retry_policy=RetryPolicy(
                maximum_attempts=5,  # More retries for payment
                initial_interval=timedelta(seconds=2),
                maximum_interval=timedelta(seconds=30),
            ),
        )
        workflow.logger.info(f"Payment: {payment_result}")

        # Step 3: Send confirmation email
        confirmation_result = await workflow.execute_activity(
            send_confirmation,
            args=[order_id, email],
            start_to_close_timeout=timedelta(seconds=30),
            retry_policy=RetryPolicy(
                maximum_attempts=3,
                initial_interval=timedelta(seconds=1),
                maximum_interval=timedelta(seconds=10),
            ),
        )
        workflow.logger.info(f"Confirmation: {confirmation_result}")

        # Workflow complete
        final_message = f"Order {order_id} completed successfully: {payment_result}"
        workflow.logger.info(final_message)

        return final_message
