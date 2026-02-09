#!/usr/bin/env python3
"""
Classify VisualWebArena templates by site with difficulty statistics.
Uses the actual 'sites' field from config for 100% accuracy.
Automatically processes all three VisualWebArena raw.json files.
"""

import json
import os
from pathlib import Path
from collections import defaultdict


def classify_templates_with_difficulty(raw_json_file, output_file):
    """
    Read the raw JSON and classify templates by site, including difficulty stats.
    """
    # Read the raw JSON file
    with open(raw_json_file, 'r') as f:
        tasks = json.load(f)

    # Data structures
    template_info = defaultdict(lambda: {
        'count': 0,
        'site': None,
        'reasoning_difficulties': [],
        'visual_difficulties': [],
        'overall_difficulties': [],
        'tasks': []
    })
    site_stats = defaultdict(lambda: {
        'count': 0,
        'total_usage': 0,
        'reasoning_difficulty_distribution': defaultdict(int),
        'visual_difficulty_distribution': defaultdict(int),
        'overall_difficulty_distribution': defaultdict(int)
    })
    templates_by_site = defaultdict(list)

    # Process each task
    for task in tasks:
        template = task.get('intent_template', '')
        sites = task.get('sites', [])
        task_id = task.get('task_id', None)

        # Difficulty info (if available)
        reasoning_difficulty = task.get('reasoning_difficulty', None)
        visual_difficulty = task.get('visual_difficulty', None)
        overall_difficulty = task.get('overall_difficulty', None)
        # Fallback for older format
        difficulty = task.get('difficulty', None)

        if not template:
            continue

        # Use the first site in the list
        site = sites[0] if sites else 'unknown'

        # Track template info
        template_info[template]['count'] += 1
        template_info[template]['site'] = site
        template_info[template]['tasks'].append(task_id)

        # Track reasoning difficulty
        if reasoning_difficulty:
            template_info[template]['reasoning_difficulties'].append(reasoning_difficulty)
            site_stats[site]['reasoning_difficulty_distribution'][reasoning_difficulty] += 1
        elif difficulty:  # Fallback
            template_info[template]['reasoning_difficulties'].append(difficulty)
            site_stats[site]['reasoning_difficulty_distribution'][difficulty] += 1

        # Track visual difficulty
        if visual_difficulty:
            template_info[template]['visual_difficulties'].append(visual_difficulty)
            site_stats[site]['visual_difficulty_distribution'][visual_difficulty] += 1

        # Track overall difficulty
        if overall_difficulty:
            template_info[template]['overall_difficulties'].append(overall_difficulty)
            site_stats[site]['overall_difficulty_distribution'][overall_difficulty] += 1

    # Build the output structure
    for template, info in template_info.items():
        site = info['site']
        count = info['count']
        reasoning_diffs = info['reasoning_difficulties']
        visual_diffs = info['visual_difficulties']
        overall_diffs = info['overall_difficulties']

        # Calculate difficulty statistics
        from collections import Counter

        difficulty_stats = {}

        if reasoning_diffs:
            diff_counts = Counter(reasoning_diffs)
            difficulty_stats['reasoning'] = {
                'distribution': dict(diff_counts),
                'most_common': diff_counts.most_common(1)[0][0] if diff_counts else None,
                'total': len(reasoning_diffs)
            }

        if visual_diffs:
            diff_counts = Counter(visual_diffs)
            difficulty_stats['visual'] = {
                'distribution': dict(diff_counts),
                'most_common': diff_counts.most_common(1)[0][0] if diff_counts else None,
                'total': len(visual_diffs)
            }

        if overall_diffs:
            diff_counts = Counter(overall_diffs)
            difficulty_stats['overall'] = {
                'distribution': dict(diff_counts),
                'most_common': diff_counts.most_common(1)[0][0] if diff_counts else None,
                'total': len(overall_diffs)
            }

        templates_by_site[site].append({
            'template': template,
            'count': count,
            'difficulty': difficulty_stats if difficulty_stats else None,
            'task_ids': info['tasks']
        })

        site_stats[site]['count'] += 1
        site_stats[site]['total_usage'] += count

    # Sort templates within each site by frequency
    for site in templates_by_site:
        templates_by_site[site].sort(key=lambda x: x['count'], reverse=True)

    # Calculate total
    total_templates = sum(stats['count'] for stats in site_stats.values())
    total_tasks = sum(stats['total_usage'] for stats in site_stats.values())

    # Create output structure
    output_data = {
        'metadata': {
            'source_file': raw_json_file,
            'total_templates': total_templates,
            'total_tasks': total_tasks,
            'classification_method': 'ground-truth (from sites field)',
            'includes_difficulty': True,
            'sites': sorted(list(site_stats.keys()))
        },
        'site_statistics': {
            site: {
                'unique_templates': stats['count'],
                'total_tasks': stats['total_usage'],
                'percentage_of_templates': round(100 * stats['count'] / total_templates, 1),
                'percentage_of_tasks': round(100 * stats['total_usage'] / total_tasks, 1),
                'reasoning_difficulty_distribution': dict(stats['reasoning_difficulty_distribution']),
                'visual_difficulty_distribution': dict(stats['visual_difficulty_distribution']),
                'overall_difficulty_distribution': dict(stats['overall_difficulty_distribution'])
            }
            for site, stats in sorted(site_stats.items(), key=lambda x: x[1]['total_usage'], reverse=True)
        },
        'templates_by_site': dict(templates_by_site)
    }

    # Save to file
    with open(output_file, 'w') as f:
        json.dump(output_data, f, indent=2)

    # Print summary
    print(f"Template Classification with Difficulty Complete!")
    print(f"\nTotal templates: {total_templates}")
    print(f"Total tasks: {total_tasks}")
    print(f"\nTemplates by Site (sorted by task count):")
    print("=" * 80)

    for site, stats in sorted(site_stats.items(), key=lambda x: x[1]['total_usage'], reverse=True):
        template_pct = 100 * stats['count'] / total_templates
        task_pct = 100 * stats['total_usage'] / total_tasks
        print(f"{site:20s}: {stats['count']:3d} templates ({template_pct:5.1f}%), "
              f"{stats['total_usage']:3d} tasks ({task_pct:5.1f}%)")

        # Show difficulty distributions for this site
        if stats['reasoning_difficulty_distribution']:
            diff_dist = stats['reasoning_difficulty_distribution']
            diff_str = ", ".join([f"{k}: {v}" for k, v in sorted(diff_dist.items())])
            print(f"{'':22s}Reasoning: {diff_str}")
        if stats['visual_difficulty_distribution']:
            diff_dist = stats['visual_difficulty_distribution']
            diff_str = ", ".join([f"{k}: {v}" for k, v in sorted(diff_dist.items())])
            print(f"{'':22s}Visual: {diff_str}")
        if stats['overall_difficulty_distribution']:
            diff_dist = stats['overall_difficulty_distribution']
            diff_str = ", ".join([f"{k}: {v}" for k, v in sorted(diff_dist.items())])
            print(f"{'':22s}Overall: {diff_str}")

    print(f"\nOutput saved to: {output_file}")

    # Show top 3 templates per site with difficulty
    print(f"\n{'='*80}")
    print("Top 3 Templates per Site (with difficulty):")
    print(f"{'='*80}")
    for site in sorted(templates_by_site.keys()):
        print(f"\n{site.upper()}:")
        for i, item in enumerate(templates_by_site[site][:3], 1):
            template_preview = item['template'][:60] + "..." if len(item['template']) > 60 else item['template']
            diff_info = ""
            if item['difficulty']:
                diff_parts = []
                if 'reasoning' in item['difficulty']:
                    diff_parts.append(f"R:{item['difficulty']['reasoning']['most_common']}")
                if 'visual' in item['difficulty']:
                    diff_parts.append(f"V:{item['difficulty']['visual']['most_common']}")
                if 'overall' in item['difficulty']:
                    diff_parts.append(f"O:{item['difficulty']['overall']['most_common']}")
                if diff_parts:
                    diff_info = f" [{', '.join(diff_parts)}]"
            print(f"  {i}. [{item['count']}x] {template_preview}{diff_info}")


if __name__ == '__main__':
    import sys

    # Get the script's directory
    script_dir = Path(__file__).parent

    # Define base directory for VisualWebArena (relative to script location)
    vwa_base_dir = script_dir / 'config_files' / 'vwa'

    # Define the three VisualWebArena files to process
    vwa_files = [
        {
            'name': 'classifieds',
            'input': vwa_base_dir / 'test_classifieds.raw.json',
            'output': vwa_base_dir / 'extracted_templates_classifieds' / 'templates_with_difficulty.json'
        },
        {
            'name': 'reddit',
            'input': vwa_base_dir / 'test_reddit.raw.json',
            'output': vwa_base_dir / 'extracted_templates_reddit' / 'templates_with_difficulty.json'
        },
        {
            'name': 'shopping',
            'input': vwa_base_dir / 'test_shopping.raw.json',
            'output': vwa_base_dir / 'extracted_templates_shopping' / 'templates_with_difficulty.json'
        }
    ]

    # If command line arguments provided, use them (backward compatibility)
    if len(sys.argv) > 1:
        raw_json_file = sys.argv[1]
        output_file = sys.argv[2] if len(sys.argv) > 2 else 'templates_with_difficulty.json'
        classify_templates_with_difficulty(raw_json_file, output_file)
    else:
        # Process all three VWA files
        print("Processing VisualWebArena files...")
        print("=" * 80)

        for file_info in vwa_files:
            print(f"\n{'='*80}")
            print(f"Processing {file_info['name'].upper()}")
            print(f"{'='*80}")
            print(f"Input:  {file_info['input']}")
            print(f"Output: {file_info['output']}")
            print()

            # Ensure output directory exists
            file_info['output'].parent.mkdir(parents=True, exist_ok=True)

            # Process this file
            classify_templates_with_difficulty(
                str(file_info['input']),
                str(file_info['output'])
            )

        print(f"\n{'='*80}")
        print("All VisualWebArena files processed successfully!")
        print(f"{'='*80}")
