#!/usr/bin/env python3
"""
Benchmark script for Orpheus-TTS streaming endpoint.
Tests time to first byte (TTFB) and overall generation speed.
"""

import time
import argparse
import requests
import json
import statistics
from datetime import datetime
import sys

def benchmark_streaming(url, text, voice="tara", emotion=None, n_runs=3):
    """
    Benchmark the streaming TTS endpoint for both TTFB and overall generation speed.
    
    Args:
        url: Streaming endpoint URL
        text: Text to convert to speech
        voice: Voice ID to use
        emotion: Optional emotion tag
        n_runs: Number of benchmark runs to perform
    
    Returns:
        Dictionary with benchmark results
    """
    results = {
        "ttfb_ms": [],
        "total_time_ms": [],
        "byte_size": [],
        "bytes_per_second": [],
        "text_length": len(text),
        "chars_per_second": []
    }
    
    headers = {"Content-Type": "application/json"}
    
    # Add emotion tag if provided
    if emotion:
        text = f"<{emotion}>{text}"
    
    data = {
        "input": text,
        "model": "orpheus",
        "voice": voice,
        "response_format": "wav",
        "speed": 1
    }
    
    print(f"\nBenchmarking with text ({len(text)} chars): '{text[:50]}...'")
    print(f"Voice: {voice}, Runs: {n_runs}")
    
    for i in range(n_runs):
        print(f"\nRun {i+1}/{n_runs}...")
        
        start_time = time.time()
        ttfb_recorded = False
        ttfb_time = None
        
        response = requests.post(url, data=json.dumps(data), headers=headers, stream=True)
        
        if response.status_code != 200:
            print(f"Error: Received status code {response.status_code}")
            print(response.text)
            continue
        
        # Process the streaming response
        chunk_count = 0
        content_bytes = bytearray()
        
        for chunk in response.iter_content(chunk_size=1024):
            if not ttfb_recorded:
                ttfb_time = time.time()
                ttfb_recorded = True
                ttfb_ms = (ttfb_time - start_time) * 1000
                results["ttfb_ms"].append(ttfb_ms)
                print(f"  TTFB: {ttfb_ms:.2f}ms")
            
            chunk_count += 1
            content_bytes.extend(chunk)
            
            # Print progress indicator
            sys.stdout.write(".")
            sys.stdout.flush()
        
        end_time = time.time()
        total_time_ms = (end_time - start_time) * 1000
        bytes_per_second = len(content_bytes) / (total_time_ms / 1000)
        chars_per_second = len(text) / (total_time_ms / 1000)
        
        results["total_time_ms"].append(total_time_ms)
        results["byte_size"].append(len(content_bytes))
        results["bytes_per_second"].append(bytes_per_second)
        results["chars_per_second"].append(chars_per_second)
        
        print(f"\n  Total time: {total_time_ms:.2f}ms")
        print(f"  Response size: {len(content_bytes)/1024:.2f}KB")
        print(f"  Speed: {bytes_per_second/1024:.2f}KB/s, {chars_per_second:.2f}chars/s")
        
        # Sleep between runs to prevent throttling
        if i < n_runs - 1:
            time.sleep(1)
    
    # Calculate statistics
    if results["ttfb_ms"]:
        print("\n=== BENCHMARK RESULTS ===")
        print(f"Text length: {len(text)} characters")
        print(f"Voice: {voice}")
        
        # TTFB stats
        ttfb_avg = statistics.mean(results["ttfb_ms"])
        ttfb_min = min(results["ttfb_ms"])
        ttfb_max = max(results["ttfb_ms"])
        ttfb_median = statistics.median(results["ttfb_ms"])
        print(f"\nTime to First Byte (TTFB):")
        print(f"  Min: {ttfb_min:.2f}ms")
        print(f"  Max: {ttfb_max:.2f}ms")
        print(f"  Avg: {ttfb_avg:.2f}ms")
        print(f"  Median: {ttfb_median:.2f}ms")
        
        # Total time stats
        total_avg = statistics.mean(results["total_time_ms"])
        total_min = min(results["total_time_ms"])
        total_max = max(results["total_time_ms"])
        total_median = statistics.median(results["total_time_ms"])
        print(f"\nTotal Generation Time:")
        print(f"  Min: {total_min:.2f}ms ({total_min/1000:.2f}s)")
        print(f"  Max: {total_max:.2f}ms ({total_max/1000:.2f}s)")
        print(f"  Avg: {total_avg:.2f}ms ({total_avg/1000:.2f}s)")
        print(f"  Median: {total_median:.2f}ms ({total_median/1000:.2f}s)")
        
        # Speed stats
        bytes_avg = statistics.mean(results["bytes_per_second"])
        chars_avg = statistics.mean(results["chars_per_second"])
        print(f"\nGeneration Speed:")
        print(f"  Avg throughput: {bytes_avg/1024:.2f}KB/s")
        print(f"  Avg text processing: {chars_avg:.2f}chars/s")
        
        # File size
        avg_size = statistics.mean(results["byte_size"])
        print(f"\nAudio Output:")
        print(f"  Avg size: {avg_size/1024:.2f}KB")
        print(f"  Bytes per character: {avg_size/len(text):.2f}")
    
    return results

def save_results(results, filename=None):
    """Save benchmark results to a file"""
    if not filename:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"benchmark_results_{timestamp}.json"
    
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to {filename}")

def main():
    parser = argparse.ArgumentParser(description="Benchmark the Orpheus-TTS streaming endpoint")
    parser.add_argument("--url", default="http://localhost:5005/v1/audio/speech/stream", 
                      help="URL of the streaming endpoint")
    parser.add_argument("--text", default="Hello world! This is a test of the Orpheus text to speech system. How does it sound?", 
                      help="Text to convert to speech")
    parser.add_argument("--voice", default="tara", 
                      help="Voice ID to use")
    parser.add_argument("--emotion", 
                      help="Optional emotion tag (without <>)")
    parser.add_argument("--runs", type=int, default=3, 
                      help="Number of benchmark runs")
    parser.add_argument("--file", 
                      help="Optional filename for saving results")
    parser.add_argument("--long-text", action="store_true", 
                      help="Use a longer sample text for benchmarking")
    
    args = parser.parse_args()
    
    if args.long_text:
        text = ("This is a longer text sample for benchmarking the Orpheus text-to-speech system. "
               "We want to measure how quickly the system can generate speech in real-time. "
               "The benchmark will measure the time to first byte, which indicates how quickly "
               "the system starts responding, as well as the overall generation speed in both "
               "bytes per second and characters per second. This helps us understand the latency "
               "and throughput characteristics of the TTS engine under various conditions. "
               "By testing with different voice models and text lengths, we can optimize the system "
               "for the best balance of quality and performance.")
        args.text = text
    
    results = benchmark_streaming(
        url=args.url,
        text=args.text,
        voice=args.voice,
        emotion=args.emotion,
        n_runs=args.runs
    )
    
    if args.file or input("\nSave results to file? (y/n): ").lower() == 'y':
        save_results(results, args.file)

if __name__ == "__main__":
    main()