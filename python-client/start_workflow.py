"""
Script to start an order processing workflow.

This demonstrates how to:
- Connect to Temporal server
- Start a workflow execution
- Get the workflow result
"""

import asyncio
import logging
import uuid
from temporalio.client import Client

# Import workflow class
from workflows.order_workflow import OrderWorkflow

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def main():
    """Start an order processing workflow."""

    # Connect to Temporal server
    logger.info("Connecting to Temporal server at localhost:7233...")
    client = await Client.connect("localhost:7233")

    # Generate a unique order ID
    order_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"

    # Workflow parameters
    amount = 99.99
    email = "customer@example.com"

    logger.info(f"Starting workflow for order: {order_id}")
    logger.info(f"Amount: ${amount}")
    logger.info(f"Email: {email}")

    # Start the workflow
    handle = await client.start_workflow(
        OrderWorkflow.run,
        args=[order_id, amount, email],
        id=f"order-workflow-{order_id}",
        task_queue="order-processing-queue",
    )

    logger.info(f"Workflow started! Workflow ID: {handle.id}")
    logger.info(f"Run ID: {handle.result_run_id}")
    logger.info("Waiting for workflow to complete...")

    # Wait for workflow to complete and get result
    result = await handle.result()

    logger.info("=" * 50)
    logger.info("WORKFLOW COMPLETED!")
    logger.info(f"Result: {result}")
    logger.info("=" * 50)
    logger.info("\nCheck the Temporal UI at http://localhost:8080 to see the workflow history!")


if __name__ == "__main__":
    asyncio.run(main())
