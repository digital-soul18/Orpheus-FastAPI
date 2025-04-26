#!/usr/bin/env python3
"""
Comprehensive benchmark script for Orpheus-TTS.
Compares different voice models, text lengths, and emotion tags.
"""

import argparse
import json
import os
from datetime import datetime
from benchmark_streaming import benchmark_streaming

# Sample texts of different lengths
SAMPLE_TEXTS = {
    "short": "Hello! How are you today?",
    
    "medium": "Welcome to Orpheus, a high-quality text-to-speech system. It converts text to natural sounding audio using advanced deep learning models.",
    
    "long": "Text-to-speech technology has come a long way in recent years. Modern systems like Orpheus can generate highly natural and expressive speech that's almost indistinguishable from human voices. This makes it useful for applications ranging from accessibility tools to interactive voice assistants. The ability to stream audio in real-time while maintaining high quality is particularly important for responsive user experiences.",
    
    "very_long": "The development of modern text-to-speech systems represents a significant achievement in artificial intelligence and digital signal processing. These systems combine advances in deep learning, linguistics, and audio engineering to create voices that can express a wide range of emotions and speaking styles. The Orpheus system exemplifies this approach, utilizing transformer-based neural networks trained on diverse speech data to generate natural, human-like speech. One of the key challenges in this field is balancing quality with performance - creating voices that sound natural while still responding quickly enough for real-time applications. Streaming architectures help address this challenge by sending audio chunks as they're generated rather than waiting for the entire utterance to complete processing. This approach significantly improves perceived responsiveness, especially for longer text passages. Another important consideration is the ability to control prosody and emotion, allowing the generated speech to convey not just the words themselves but the appropriate tone and feeling behind them. This emotional expressivity is what truly brings synthetic speech to life and makes it engaging for human listeners."
}

# Available voices
AVAILABLE_VOICES = ["tara", "zac", "leah"]

# Emotion tags
EMOTION_TAGS = [None, "happy", "sad", "excited", "calm", "contemplative"]

def run_comprehensive_benchmark(url, output_dir, voice_subset=None, skip_long=False):
    """
    Run comprehensive benchmarks with different voices, text lengths, and emotions.
    
    Args:
        url: Streaming endpoint URL
        output_dir: Directory to save results
        voice_subset: List of voices to test (None for all)
        skip_long: Skip very long text samples
    """
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    voices = voice_subset if voice_subset else AVAILABLE_VOICES
    texts = SAMPLE_TEXTS.copy()
    if skip_long:
        texts.pop("very_long", None)
    
    all_results = {}
    
    # For each voice
    for voice in voices:
        voice_results = {}
        print(f"\n\n=== BENCHMARKING VOICE: {voice} ===")
        
        # For each text length
        for text_name, text in texts.items():
            print(f"\n== Testing {text_name} text ({len(text)} chars) ==")
            
            # Test with no emotion
            results = benchmark_streaming(
                url=url,
                text=text,
                voice=voice,
                emotion=None,
                n_runs=3
            )
            
            # Save individual result
            voice_results[f"{text_name}_neutral"] = results
            
            # Test with one emotion (happy)
            if text_name != "very_long":  # Skip emotions on very long text to save time
                emotion = "happy"
                print(f"\n== Testing {text_name} text with {emotion} emotion ==")
                results = benchmark_streaming(
                    url=url,
                    text=text,
                    voice=voice,
                    emotion=emotion,
                    n_runs=2  # Fewer runs for emotion tests
                )
                voice_results[f"{text_name}_{emotion}"] = results
        
        all_results[voice] = voice_results
        
        # Save results for this voice
        voice_filename = os.path.join(output_dir, f"benchmark_{voice}_{timestamp}.json")
        with open(voice_filename, 'w') as f:
            json.dump(voice_results, f, indent=2)
        print(f"\nResults for voice '{voice}' saved to {voice_filename}")
    
    # Save combined results
    combined_filename = os.path.join(output_dir, f"benchmark_all_{timestamp}.json")
    with open(combined_filename, 'w') as f:
        json.dump(all_results, f, indent=2)
    print(f"\nCombined results saved to {combined_filename}")
    
    # Generate summary report
    generate_summary_report(all_results, os.path.join(output_dir, f"benchmark_summary_{timestamp}.txt"))
    
    return all_results

def generate_summary_report(results, filename):
    """Generate a human-readable summary report of benchmark results"""
    with open(filename, 'w') as f:
        f.write("=== ORPHEUS TTS BENCHMARK SUMMARY ===\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        
        # TTFB Summary
        f.write("== TIME TO FIRST BYTE (TTFB) ==\n")
        f.write("Voice      | Short Text | Medium Text | Long Text\n")
        f.write("-----------+------------+-------------+----------\n")
        
        for voice in results:
            voice_data = results[voice]
            short_ttfb = mean_or_na(voice_data.get("short_neutral", {}).get("ttfb_ms", []))
            medium_ttfb = mean_or_na(voice_data.get("medium_neutral", {}).get("ttfb_ms", []))
            long_ttfb = mean_or_na(voice_data.get("long_neutral", {}).get("ttfb_ms", []))
            
            f.write(f"{voice:10} | {short_ttfb:10} | {medium_ttfb:11} | {long_ttfb:10}\n")
        
        # Total Time Summary
        f.write("\n\n== TOTAL GENERATION TIME (seconds) ==\n")
        f.write("Voice      | Short Text | Medium Text | Long Text\n")
        f.write("-----------+------------+-------------+----------\n")
        
        for voice in results:
            voice_data = results[voice]
            short_time = mean_or_na(voice_data.get("short_neutral", {}).get("total_time_ms", []), divide_by=1000)
            medium_time = mean_or_na(voice_data.get("medium_neutral", {}).get("total_time_ms", []), divide_by=1000)
            long_time = mean_or_na(voice_data.get("long_neutral", {}).get("total_time_ms", []), divide_by=1000)
            
            f.write(f"{voice:10} | {short_time:10} | {medium_time:11} | {long_time:10}\n")
        
        # Character Processing Rate
        f.write("\n\n== CHARACTERS PER SECOND ==\n")
        f.write("Voice      | Short Text | Medium Text | Long Text\n")
        f.write("-----------+------------+-------------+----------\n")
        
        for voice in results:
            voice_data = results[voice]
            short_cps = mean_or_na(voice_data.get("short_neutral", {}).get("chars_per_second", []))
            medium_cps = mean_or_na(voice_data.get("medium_neutral", {}).get("chars_per_second", []))
            long_cps = mean_or_na(voice_data.get("long_neutral", {}).get("chars_per_second", []))
            
            f.write(f"{voice:10} | {short_cps:10} | {medium_cps:11} | {long_cps:10}\n")
        
        # Emotion comparison for one voice and text length
        main_voice = list(results.keys())[0]
        f.write(f"\n\n== EMOTION IMPACT (voice: {main_voice}, medium text) ==\n")
        f.write("Emotion    | TTFB (ms)  | Total Time (s) | Chars/second\n")
        f.write("-----------+------------+----------------+-------------\n")
        
        if main_voice in results:
            voice_data = results[main_voice]
            neutral_data = voice_data.get("medium_neutral", {})
            happy_data = voice_data.get("medium_happy", {})
            
            neutral_ttfb = mean_or_na(neutral_data.get("ttfb_ms", []))
            neutral_time = mean_or_na(neutral_data.get("total_time_ms", []), divide_by=1000)
            neutral_cps = mean_or_na(neutral_data.get("chars_per_second", []))
            
            happy_ttfb = mean_or_na(happy_data.get("ttfb_ms", []))
            happy_time = mean_or_na(happy_data.get("total_time_ms", []), divide_by=1000)
            happy_cps = mean_or_na(happy_data.get("chars_per_second", []))
            
            f.write(f"neutral    | {neutral_ttfb:10} | {neutral_time:14} | {neutral_cps:13}\n")
            f.write(f"happy      | {happy_ttfb:10} | {happy_time:14} | {happy_cps:13}\n")
        
        f.write("\n\nNote: All values are averages across benchmark runs\n")
    
    print(f"Summary report saved to {filename}")

def mean_or_na(values, divide_by=1):
    """Calculate mean of values or return 'N/A' if empty"""
    if not values:
        return "N/A"
    return f"{sum(values) / len(values) / divide_by:.2f}"

def main():
    parser = argparse.ArgumentParser(description="Comprehensive Orpheus-TTS benchmark")
    parser.add_argument("--url", default="http://localhost:5005/v1/audio/speech/stream", 
                      help="URL of the streaming endpoint")
    parser.add_argument("--output", default="benchmark_results", 
                      help="Directory to save benchmark results")
    parser.add_argument("--voices", nargs="+", choices=AVAILABLE_VOICES,
                      help="Specific voices to test (default: all)")
    parser.add_argument("--skip-long", action="store_true",
                      help="Skip very long text samples to save time")
    
    args = parser.parse_args()
    
    run_comprehensive_benchmark(
        url=args.url,
        output_dir=args.output,
        voice_subset=args.voices,
        skip_long=args.skip_long
    )

if __name__ == "__main__":
    main()