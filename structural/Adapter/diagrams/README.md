# Mermaid Diagrams to Images

이 디렉토리는 BLOG_POST.md에서 추출한 Mermaid 다이어그램과 이를 이미지로 변환하는 방법을 담고 있습니다.

## 디렉토리 구조

```
diagrams/
├── README.md          # 이 파일
├── mermaid/          # Mermaid 소스 파일 (.mmd)
│   ├── graph_01.mmd
│   ├── sequence_04.mmd
│   └── ...
└── images/           # 변환된 이미지 (PNG/SVG)
    ├── graph_01.png
    ├── sequence_04.png
    └── ...
```

## 다이어그램 목록

블로그 포스트에 포함된 10개의 다이어그램:

1. `graph_01.mmd` - GoF to Kubernetes 개념 전환
2. `graph_02.mmd` - Kubernetes Pod 아키텍처
3. `graph_03.mmd` - Sidecar vs Adapter vs Ambassador
4. `sequence_04.mmd` - JMX Exporter 시퀀스
5. `graph_05.mmd` - 로그 형식 변환 플로우
6. `sequence_06.mmd` - Traditional Sidecar 문제
7. `sequence_07.mmd` - Native Sidecar 해결
8. `state_08.mmd` - Native Sidecar 라이프사이클
9. `graph_09.mmd` - 멀티 서비스 모니터링
10. `graph_10.mmd` - 트러블슈팅 Decision Tree

## 이미지 변환 방법

### 방법 1: Mermaid CLI (권장)

Node.js와 npm이 설치되어 있어야 합니다.

```bash
# Mermaid CLI 설치
npm install -g @mermaid-js/mermaid-cli

# 변환 디렉토리로 이동
cd diagrams/mermaid

# 단일 파일 변환
mmdc -i graph_01.mmd -o ../images/graph_01.png -b transparent

# 모든 파일 일괄 변환 (PNG)
for file in *.mmd; do
  mmdc -i "$file" -o "../images/${file%.mmd}.png" -b transparent
done

# SVG로 변환 (벡터, 고품질)
for file in *.mmd; do
  mmdc -i "$file" -o "../images/${file%.mmd}.svg"
done
```

#### 옵션 설명

- `-i`: 입력 파일
- `-o`: 출력 파일
- `-b transparent`: 배경 투명
- `-w 1200`: 이미지 너비 (기본 800px)
- `-H 800`: 이미지 높이

### 방법 2: npx 사용 (설치 없이)

npm이 설치되어 있으면 npx로 즉시 사용 가능:

```bash
cd diagrams/mermaid

# npx로 변환
for file in *.mmd; do
  npx -p @mermaid-js/mermaid-cli mmdc \
    -i "$file" \
    -o "../images/${file%.mmd}.png" \
    -b transparent \
    -w 1200
done
```

### 방법 3: Docker 사용

Docker만 있으면 환경에 독립적으로 사용 가능:

```bash
cd diagrams/mermaid

# Docker로 변환
for file in *.mmd; do
  docker run --rm \
    -v $(pwd):/data \
    minlag/mermaid-cli \
    -i "/data/$file" \
    -o "/data/../images/${file%.mmd}.png" \
    -b transparent
done
```

### 방법 4: 온라인 도구

GUI를 선호하는 경우:

1. **Mermaid Live Editor** (https://mermaid.live)
   - .mmd 파일 내용 복사
   - 에디터에 붙여넣기
   - Actions → Export → PNG/SVG

2. **Mermaid Chart** (https://www.mermaidchart.com)
   - 계정 필요
   - 더 많은 테마와 커스터마이징 옵션

### 방법 5: VS Code Extension

VS Code 사용자:

1. Extension 설치: "Markdown Preview Mermaid Support"
2. Markdown 파일에서 Mermaid 코드 작성
3. 미리보기로 확인
4. 우클릭 → Export to PNG

## 자동화 스크립트

### 일괄 변환 스크립트 (Bash)

`scripts/convert-all.sh`:

```bash
#!/bin/bash
set -e

MERMAID_DIR="diagrams/mermaid"
OUTPUT_DIR="diagrams/images"

mkdir -p "$OUTPUT_DIR"

echo "Converting Mermaid diagrams to PNG..."

for file in "$MERMAID_DIR"/*.mmd; do
  filename=$(basename "$file" .mmd)
  echo "Converting $filename..."

  mmdc -i "$file" \
       -o "$OUTPUT_DIR/${filename}.png" \
       -b transparent \
       -w 1200

  echo "✓ $filename.png"
done

echo ""
echo "Conversion complete!"
echo "Images saved to: $OUTPUT_DIR"
```

실행:

```bash
chmod +x scripts/convert-all.sh
./scripts/convert-all.sh
```

### Python 자동화

`scripts/convert-mermaid.py`:

```python
#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path

def convert_mermaid_to_png(mermaid_dir, output_dir):
    """Mermaid 파일을 PNG로 변환"""

    mermaid_dir = Path(mermaid_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    mmd_files = list(mermaid_dir.glob('*.mmd'))

    print(f"Found {len(mmd_files)} Mermaid files\n")

    for mmd_file in mmd_files:
        output_file = output_dir / f"{mmd_file.stem}.png"

        print(f"Converting {mmd_file.name}...")

        cmd = [
            'mmdc',
            '-i', str(mmd_file),
            '-o', str(output_file),
            '-b', 'transparent',
            '-w', '1200'
        ]

        try:
            subprocess.run(cmd, check=True, capture_output=True)
            print(f"  ✓ {output_file.name}\n")
        except subprocess.CalledProcessError as e:
            print(f"  ✗ Error: {e}\n")

    print("Conversion complete!")

if __name__ == '__main__':
    convert_mermaid_to_png('diagrams/mermaid', 'diagrams/images')
```

## 이미지 품질 최적화

### 고해상도 PNG

```bash
mmdc -i input.mmd -o output.png -b transparent -w 2400 -s 2
```

### SVG (벡터, 무한 확대 가능)

```bash
mmdc -i input.mmd -o output.svg
```

### 테마 변경

```bash
# 다크 모드
mmdc -i input.mmd -o output.png -t dark

# 커스텀 CSS
mmdc -i input.mmd -o output.png -C custom-theme.css
```

## 블로그 포스트 업데이트

이미지 변환 후 블로그 포스트에서 Mermaid 코드를 이미지로 교체:

### 변경 전 (Mermaid 코드)

```markdown
```mermaid
graph LR
    A --> B
```
```

### 변경 후 (이미지)

```markdown
![Architecture Diagram](diagrams/images/graph_01.png)
```

## 문제 해결

### mmdc 명령을 찾을 수 없음

```bash
# 전역 설치 확인
npm list -g @mermaid-js/mermaid-cli

# 재설치
npm install -g @mermaid-js/mermaid-cli
```

### Puppeteer 에러

```bash
# Puppeteer 의존성 설치 (Linux)
sudo apt-get install -y \
  gconf-service libasound2 libatk1.0-0 libc6 libcairo2 \
  libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 \
  libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 \
  libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 \
  libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 \
  libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 \
  libxrender1 libxss1 libxtst6 ca-certificates \
  fonts-liberation libappindicator1 libnss3 lsb-release \
  xdg-utils wget

# macOS
brew install chromium
```

### 메모리 부족

큰 다이어그램의 경우:

```bash
# Node 메모리 증가
NODE_OPTIONS="--max-old-space-size=4096" mmdc -i large.mmd -o large.png
```

## 참고 자료

- [Mermaid 공식 문서](https://mermaid.js.org/)
- [Mermaid CLI GitHub](https://github.com/mermaid-js/mermaid-cli)
- [Mermaid Live Editor](https://mermaid.live)
- [Mermaid Chart](https://www.mermaidchart.com)

## 라이선스

변환된 이미지는 원본 BLOG_POST.md와 동일한 라이선스를 따릅니다.
