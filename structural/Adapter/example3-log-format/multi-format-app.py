#!/usr/bin/env python3
"""
Multi-Format Logging Application
Simulates a legacy application that writes logs in various non-standard formats
"""
import time
import random
import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

LOG_FILE = os.environ.get('LOG_FILE', '/var/log/app/application.log')

class MultiFormatHandler(BaseHTTPRequestHandler):
    log_formats = [
        'apache',   # Apache Common Log Format
        'custom',   # Custom application format
        'syslog',   # Syslog-like format
        'csv'       # CSV format
    ]

    def do_GET(self):
        if self.path == '/api/data':
            self.handle_request()
        elif self.path == '/health':
            self.handle_health()
        else:
            self.send_error(404)

    def handle_request(self):
        start = time.time()
        status = 200

        # Randomly simulate errors
        if random.random() < 0.1:
            status = 500

        duration_ms = (time.time() - start) * 1000

        # Write log in random format
        log_format = random.choice(self.log_formats)
        self.write_log(log_format, status, duration_ms)

        # Send response
        if status == 200:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"success","data":123}')
        else:
            self.send_error(500)

    def write_log(self, log_format, status, duration_ms):
        try:
            with open(LOG_FILE, 'a') as f:
                if log_format == 'apache':
                    # Apache Common Log Format
                    # 127.0.0.1 - - [10/Oct/2000:13:55:36 -0700] "GET /api/data HTTP/1.0" 200 2326
                    timestamp = datetime.now().strftime('%d/%b/%Y:%H:%M:%S %z')
                    log_line = f'127.0.0.1 - - [{timestamp}] "GET /api/data HTTP/1.1" {status} 2326\n'

                elif log_format == 'custom':
                    # Custom application format
                    # [2024-01-15 10:30:45] INFO: Request processed | status=200 | duration=45ms
                    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    level = "INFO" if status == 200 else "ERROR"
                    log_line = f'[{timestamp}] {level}: Request processed | status={status} | duration={duration_ms:.2f}ms\n'

                elif log_format == 'syslog':
                    # Syslog-like format
                    # Jan 15 10:30:45 hostname app[12345]: Request status=200 duration=45ms
                    timestamp = datetime.now().strftime('%b %d %H:%M:%S')
                    log_line = f'{timestamp} localhost app[{os.getpid()}]: Request status={status} duration={duration_ms:.2f}ms\n'

                else:  # csv
                    # CSV format
                    # timestamp,level,status,duration_ms
                    timestamp = datetime.now().isoformat()
                    level = "INFO" if status == 200 else "ERROR"
                    log_line = f'{timestamp},{level},{status},{duration_ms:.2f}\n'

                f.write(log_line)

        except Exception as e:
            print(f"Error writing log: {e}")

    def handle_health(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status":"healthy"}')

    def log_message(self, format, *args):
        pass  # Suppress default HTTP logs

def main():
    port = int(os.environ.get('PORT', 8080))

    # Ensure log directory exists
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

    # Write CSV header
    if not os.path.exists(LOG_FILE):
        with open(LOG_FILE, 'w') as f:
            f.write('# Multi-format log file\n')

    server = HTTPServer(('0.0.0.0', port), MultiFormatHandler)
    print(f"Multi-Format App started on port {port}")
    print(f"Logging to: {LOG_FILE}")
    server.serve_forever()

if __name__ == '__main__':
    main()
