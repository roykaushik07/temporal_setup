# Temporal Python Client - Order Processing Demo

This is a sample Python application demonstrating how to use Temporal for workflow orchestration.

## Overview

This demo implements a simple **order processing workflow** with three steps:

1. **Validate Order** - Check order details
2. **Process Payment** - Handle payment transaction
3. **Send Confirmation** - Email customer

## Project Structure

```
python-client/
├── workflows/
│   └── order_workflow.py      # Workflow definition
├── activities/
│   └── order_activities.py    # Activity implementations
├── worker.py                   # Worker process (executes workflows)
├── start_workflow.py           # Script to trigger workflows
├── requirements.txt            # Python dependencies
└── README.md                   # This file
```

## Prerequisites

- ✅ Python 3.8+ installed
- ✅ Temporal server running (localhost:7233)
- ✅ Temporal UI accessible (localhost:8080)

## Setup

### 1. Create Virtual Environment

```bash
cd python-client

# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate  # On Mac/Linux
# OR
venv\Scripts\activate  # On Windows
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

You should see:
```
Installing temporalio==1.7.1
Installing python-dotenv==1.0.0
```

## Running the Demo

You need **two terminal windows** (both with venv activated):

### Terminal 1: Start the Worker

The worker polls Temporal for tasks and executes them.

```bash
cd python-client
source venv/bin/activate
python worker.py
```

**You should see:**
```
INFO:__main__:Connecting to Temporal server at localhost:7233...
INFO:__main__:Connected! Starting worker...
INFO:__main__:Worker started. Polling for tasks on 'order-processing-queue'...
INFO:__main__:Press Ctrl+C to stop
```

**Leave this running!**

### Terminal 2: Start a Workflow

This triggers a new order workflow.

```bash
cd python-client
source venv/bin/activate
python start_workflow.py
```

**You should see:**
```
INFO:__main__:Connecting to Temporal server at localhost:7233...
INFO:__main__:Starting workflow for order: ORD-ABC12345
INFO:__main__:Amount: $99.99
INFO:__main__:Email: customer@example.com
INFO:__main__:Workflow started! Workflow ID: order-workflow-ORD-ABC12345
INFO:__main__:Waiting for workflow to complete...
```

Watch Terminal 1 (worker) execute the activities:
```
INFO:activities.order_activities:Validating order: ORD-ABC12345
INFO:activities.order_activities:Order ORD-ABC12345 validated successfully
INFO:activities.order_activities:Processing payment for order ORD-ABC12345: $99.99
INFO:activities.order_activities:Payment processed: TXN-ORD-ABC12345-1234567890
INFO:activities.order_activities:Sending confirmation for order ORD-ABC12345 to customer@example.com
INFO:activities.order_activities:Confirmation sent to customer@example.com
```

Terminal 2 shows completion:
```
==================================================
WORKFLOW COMPLETED!
Result: Order ORD-ABC12345 completed successfully: Payment processed: TXN-...
==================================================
```

### 3. View in Temporal UI

1. Open http://localhost:8080
2. You should see your workflow execution!
3. Click on it to see:
   - Full execution history
   - Each activity execution
   - Timing information
   - Input/output data

## How It Works

### Workflow (`workflows/order_workflow.py`)

The workflow **orchestrates** the process:
- Defines the order of operations
- Handles retries and timeouts
- Maintains state durably
- Can resume after failures

```python
@workflow.defn
class OrderWorkflow:
    @workflow.run
    async def run(self, order_id: str, amount: float, email: str) -> str:
        # Step 1: Validate
        await workflow.execute_activity(validate_order, ...)
        # Step 2: Payment
        await workflow.execute_activity(process_payment, ...)
        # Step 3: Confirm
        await workflow.execute_activity(send_confirmation, ...)
```

### Activities (`activities/order_activities.py`)

Activities are **individual tasks**:
- Can fail and retry
- Execute business logic
- Can call external services
- Are monitored by Temporal

```python
@activity.defn
async def validate_order(order_id: str) -> str:
    # Validation logic here
    return "Order validated"
```

### Worker (`worker.py`)

The worker:
- Connects to Temporal server
- Polls the task queue for work
- Executes workflows and activities
- Reports results back to Temporal

### Start Script (`start_workflow.py`)

This client:
- Connects to Temporal
- Starts a workflow execution
- Waits for completion
- Returns the result

## Key Concepts Demonstrated

### 1. Durable Execution
If the worker crashes:
- Workflow state is preserved in Temporal
- Another worker can pick up and continue
- No duplicate work

### 2. Retry Policies
Each activity has retry configuration:
```python
retry_policy=RetryPolicy(
    maximum_attempts=3,
    initial_interval=timedelta(seconds=1),
)
```

### 3. Timeouts
Activities have time limits:
```python
start_to_close_timeout=timedelta(seconds=30)
```

### 4. Sequential Execution
Activities run one after another:
```
Validate → Payment → Confirmation
```

### 5. Observability
Every step is logged and visible in the Temporal UI.

## Troubleshooting

### Worker won't connect

**Error:** `Cannot connect to localhost:7233`

**Solution:**
```bash
# Check Temporal is running
cd ../temporal-compose
docker-compose ps

# Should show temporal-server as Up
```

### Import errors

**Error:** `ModuleNotFoundError: No module named 'temporalio'`

**Solution:**
```bash
# Make sure venv is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### Workflow not appearing in UI

**Check:**
1. Worker is running (Terminal 1)
2. Workflow was started successfully (Terminal 2)
3. UI is accessible at http://localhost:8080
4. You're looking at the correct namespace ("default")

### Activities not executing

**Check:**
1. Worker logs for errors
2. Task queue names match:
   - worker.py: `task_queue="order-processing-queue"`
   - start_workflow.py: `task_queue="order-processing-queue"`

## Next Steps

### Modify the Workflow

Try changing the workflow in `workflows/order_workflow.py`:
- Add more activities
- Change retry policies
- Add conditional logic
- Implement timers/delays

### Add Error Handling

```python
try:
    await workflow.execute_activity(risky_activity, ...)
except Exception as e:
    # Handle failure
    await workflow.execute_activity(compensate, ...)
```

### Run Multiple Workflows

```bash
# Terminal 2 - run multiple times
python start_workflow.py
python start_workflow.py
python start_workflow.py
```

Each gets a unique ID and executes independently!

### Deploy Worker to Kubernetes

The worker can run anywhere with network access to Temporal:
- Local machine (development)
- Docker container
- Kubernetes pod (production)
- AWS ECS/Fargate
- Your corporate EKS!

## For Production

When deploying to your corporate environment:

1. **Update connection string:**
   ```python
   # worker.py
   client = await Client.connect("temporal.your-company.com:7233")
   ```

2. **Add authentication** (if enabled in HELM chart)

3. **Deploy worker as Kubernetes Deployment:**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: order-worker
   spec:
     replicas: 3  # Scale as needed
     template:
       spec:
         containers:
         - name: worker
           image: your-nexus/order-worker:latest
           command: ["python", "worker.py"]
   ```

4. **Use environment variables for configuration**

5. **Add proper logging and monitoring**

## Resources

- [Temporal Python SDK Docs](https://docs.temporal.io/dev-guide/python)
- [Temporal Concepts](https://docs.temporal.io/concepts)
- [Python SDK API Reference](https://python.temporal.io/)

## Summary

This demo shows:
- ✅ How to define workflows and activities
- ✅ How to run a worker
- ✅ How to start workflows
- ✅ How to view execution in UI
- ✅ How Temporal handles retries and failures

**You're now ready to build production workflows with Temporal!**
