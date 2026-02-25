import boto3
import logging
from datetime import datetime, timezone, timedelta
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to delete EC2 snapshots older than one year.
    """

    ec2 = boto3.client("ec2")

    # Calculate cutoff date (1 year ago from now)
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=365)

    logger.info(f"Snapshot cleanup started. Cutoff date: {cutoff_date.isoformat()}")

    try:
        # Retrieve all snapshots owned by this account
        response = ec2.describe_snapshots(OwnerIds=["self"])
        snapshots = response.get("Snapshots", [])

    except ClientError as e:
        logger.error(f"Error retrieving snapshots: {e}")
        return {
            "statusCode": 500,
            "body": "Failed to retrieve snapshots"
        }

    deleted_count = 0

    for snapshot in snapshots:
        snapshot_id = snapshot.get("SnapshotId")
        start_time = snapshot.get("StartTime")

        if not start_time:
            continue

        # Ensure timezone-aware comparison
        if start_time < cutoff_date:
            try:
                logger.info(f"Deleting snapshot: {snapshot_id} (Created: {start_time})")

                ec2.delete_snapshot(SnapshotId=snapshot_id)

                deleted_count += 1

            except ClientError as e:
                logger.error(f"Failed to delete snapshot {snapshot_id}: {e}")

    logger.info(f"Snapshot cleanup completed. Deleted {deleted_count} snapshot(s).")

    return {
        "statusCode": 200,
        "body": f"Deleted {deleted_count} snapshot(s) older than one year."
    }
