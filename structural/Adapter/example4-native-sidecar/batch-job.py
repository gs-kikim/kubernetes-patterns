#!/usr/bin/env python3
"""
Batch Job Application
Processes data and writes metrics to a file
Demonstrates Native Sidecar with Jobs
"""
import json
import os
import time
import random
from datetime import datetime

METRICS_FILE = os.environ.get('METRICS_FILE', '/data/metrics.json')
TOTAL_ITEMS = int(os.environ.get('TOTAL_ITEMS', 100))

def process_item(item_id):
    """Simulate processing a single item"""
    # Random processing time
    processing_time = random.uniform(0.1, 0.5)
    time.sleep(processing_time)

    # Random success/failure (90% success)
    success = random.random() > 0.1

    return {
        'item_id': item_id,
        'success': success,
        'processing_time_ms': processing_time * 1000,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }

def write_metrics(metrics):
    """Write metrics to JSON file"""
    try:
        with open(METRICS_FILE, 'w') as f:
            json.dump(metrics, f, indent=2)
    except Exception as e:
        print(f"Error writing metrics: {e}")

def main():
    print(f"Batch Job started: processing {TOTAL_ITEMS} items")
    print(f"Metrics file: {METRICS_FILE}")

    # Ensure metrics directory exists
    os.makedirs(os.path.dirname(METRICS_FILE), exist_ok=True)

    metrics = {
        'job_start': datetime.utcnow().isoformat() + 'Z',
        'total_items': TOTAL_ITEMS,
        'processed': 0,
        'successful': 0,
        'failed': 0,
        'total_processing_time_ms': 0,
        'items': []
    }

    # Process items
    for i in range(1, TOTAL_ITEMS + 1):
        result = process_item(i)

        metrics['processed'] += 1
        if result['success']:
            metrics['successful'] += 1
        else:
            metrics['failed'] += 1

        metrics['total_processing_time_ms'] += result['processing_time_ms']
        metrics['items'].append(result)

        # Write metrics periodically
        if i % 10 == 0:
            write_metrics(metrics)
            print(f"Progress: {i}/{TOTAL_ITEMS} items processed "
                  f"(success: {metrics['successful']}, failed: {metrics['failed']})")

    # Final metrics
    metrics['job_end'] = datetime.utcnow().isoformat() + 'Z'
    metrics['success_rate'] = (metrics['successful'] / metrics['processed']) * 100

    write_metrics(metrics)

    print(f"\nBatch Job completed!")
    print(f"Total: {metrics['processed']} items")
    print(f"Success: {metrics['successful']} ({metrics['success_rate']:.2f}%)")
    print(f"Failed: {metrics['failed']}")
    print(f"Total time: {metrics['total_processing_time_ms']/1000:.2f}s")

    # Return exit code based on success rate
    if metrics['success_rate'] < 80:
        print("Warning: Success rate below 80%")
        return 1

    return 0

if __name__ == '__main__':
    exit(main())
