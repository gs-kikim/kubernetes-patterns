#!/usr/bin/env python3
"""
BLOG_POST.md에서 Mermaid 다이어그램을 추출하여 개별 .mmd 파일로 저장
"""
import re
import os
from pathlib import Path

def extract_mermaid_diagrams(markdown_file):
    """Markdown 파일에서 모든 Mermaid 다이어그램 추출"""

    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Mermaid 코드블록 패턴 (```mermaid ... ```)
    pattern = r'```mermaid\n(.*?)\n```'
    matches = re.findall(pattern, content, re.DOTALL)

    return matches

def save_mermaid_files(diagrams, output_dir):
    """추출한 다이어그램을 개별 파일로 저장"""

    os.makedirs(output_dir, exist_ok=True)

    saved_files = []
    for idx, diagram in enumerate(diagrams, 1):
        # 다이어그램 타입 감지
        first_line = diagram.strip().split('\n')[0]

        if 'graph' in first_line:
            diagram_type = 'graph'
        elif 'sequenceDiagram' in first_line:
            diagram_type = 'sequence'
        elif 'stateDiagram' in first_line:
            diagram_type = 'state'
        else:
            diagram_type = 'diagram'

        filename = f"{diagram_type}_{idx:02d}.mmd"
        filepath = os.path.join(output_dir, filename)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(diagram.strip())

        saved_files.append(filepath)
        print(f"Saved: {filename}")

    return saved_files

def main():
    # 경로 설정
    script_dir = Path(__file__).parent
    adapter_dir = script_dir.parent
    blog_file = adapter_dir / 'BLOG_POST.md'
    output_dir = adapter_dir / 'diagrams' / 'mermaid'

    print(f"Reading from: {blog_file}")

    # Mermaid 다이어그램 추출
    diagrams = extract_mermaid_diagrams(blog_file)
    print(f"\nFound {len(diagrams)} Mermaid diagrams")

    # 파일로 저장
    print(f"\nSaving to: {output_dir}\n")
    saved_files = save_mermaid_files(diagrams, output_dir)

    print(f"\nTotal saved: {len(saved_files)} files")

    # 변환 명령어 생성
    print("\n" + "="*60)
    print("다음 명령어로 이미지로 변환할 수 있습니다:")
    print("="*60)
    print("\n# 방법 1: npx 사용 (권장)")
    print(f"cd {output_dir}")
    print('for file in *.mmd; do')
    print('  npx -p @mermaid-js/mermaid-cli mmdc -i "$file" -o "${file%.mmd}.png" -b transparent')
    print('done')

    print("\n# 방법 2: Docker 사용")
    print(f"cd {output_dir}")
    print('for file in *.mmd; do')
    print('  docker run --rm -v $(pwd):/data minlag/mermaid-cli -i "/data/$file" -o "/data/${file%.mmd}.png"')
    print('done')

    print("\n# 방법 3: SVG로 변환 (벡터 이미지)")
    print(f"cd {output_dir}")
    print('for file in *.mmd; do')
    print('  npx -p @mermaid-js/mermaid-cli mmdc -i "$file" -o "${file%.mmd}.svg"')
    print('done')

if __name__ == '__main__':
    main()
