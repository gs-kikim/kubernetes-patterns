#!/usr/bin/env python3
"""
Random Number Generator - Main Application
Generates random numbers and logs generation time to a custom log file
"""
import random
import time
import json
import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

LOG_FILE = os.environ.get('LOG_FILE', '/var/log/random.log')

class RandomGeneratorHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/random':
            self.handle_random()
        elif self.path == '/health':
            self.handle_health()
        else:
            self.send_error(404)

    def handle_random(self):
        start = time.time()

        # Generate random number (simulating real work)
        result = random.randint(1, 1000)
        time.sleep(random.uniform(0.01, 0.1))

        duration_ms = (time.time() - start) * 1000

        # Write custom log format
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "operation": "random_generation",
            "duration_ms": round(duration_ms, 2),
            "value": result
        }

        try:
            with open(LOG_FILE, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            print(f"Error writing to log file: {e}")

        # Send response
        response = json.dumps({
            "random_number": result,
            "generation_time_ms": round(duration_ms, 2)
        })

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(response.encode())

    def handle_health(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status":"healthy"}')

    def log_message(self, format, *args):
        # Suppress default HTTP logs
        pass

def main():
    port = int(os.environ.get('PORT', 8080))

    # Ensure log directory exists
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

    server = HTTPServer(('0.0.0.0', port), RandomGeneratorHandler)
    print(f"Random Generator Server started on port {port}")
    print(f"Logging to: {LOG_FILE}")
    server.serve_forever()

if __name__ == '__main__':
    main()
