#!/bin/bash
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MERMAID_DIR="$PROJECT_DIR/diagrams/mermaid"
OUTPUT_DIR="$PROJECT_DIR/diagrams/images"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Mermaid to Image Converter${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# 출력 디렉토리 생성
mkdir -p "$OUTPUT_DIR"

# 변환 방법 확인
if command -v mmdc &> /dev/null; then
    CONVERTER="mmdc"
    echo -e "${GREEN}Using: mermaid-cli (mmdc)${NC}"
elif command -v npx &> /dev/null; then
    CONVERTER="npx"
    echo -e "${GREEN}Using: npx${NC}"
elif command -v docker &> /dev/null; then
    CONVERTER="docker"
    echo -e "${GREEN}Using: Docker${NC}"
else
    echo -e "${RED}Error: No converter found${NC}"
    echo ""
    echo "Please install one of the following:"
    echo "  1. npm install -g @mermaid-js/mermaid-cli"
    echo "  2. Install npm/npx"
    echo "  3. Install Docker"
    exit 1
fi

echo ""
echo "Converting Mermaid diagrams to PNG..."
echo "Source: $MERMAID_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# 변환 카운터
TOTAL=0
SUCCESS=0
FAILED=0

# 모든 .mmd 파일 변환
for file in "$MERMAID_DIR"/*.mmd; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .mmd)
        output_file="$OUTPUT_DIR/${filename}.png"

        TOTAL=$((TOTAL + 1))
        echo -e "${YELLOW}[$TOTAL] Converting $filename...${NC}"

        case $CONVERTER in
            mmdc)
                if mmdc -i "$file" -o "$output_file" -b transparent -w 1200 > /dev/null 2>&1; then
                    SUCCESS=$((SUCCESS + 1))
                    echo -e "    ${GREEN}✓ $filename.png${NC}"
                else
                    FAILED=$((FAILED + 1))
                    echo -e "    ${RED}✗ Failed${NC}"
                fi
                ;;

            npx)
                if npx -y -p @mermaid-js/mermaid-cli mmdc -i "$file" -o "$output_file" -b transparent -w 1200 > /dev/null 2>&1; then
                    SUCCESS=$((SUCCESS + 1))
                    echo -e "    ${GREEN}✓ $filename.png${NC}"
                else
                    FAILED=$((FAILED + 1))
                    echo -e "    ${RED}✗ Failed${NC}"
                fi
                ;;

            docker)
                if docker run --rm -v "$PROJECT_DIR/diagrams:/data" minlag/mermaid-cli \
                    -i "/data/mermaid/${filename}.mmd" \
                    -o "/data/images/${filename}.png" \
                    -b transparent -w 1200 > /dev/null 2>&1; then
                    SUCCESS=$((SUCCESS + 1))
                    echo -e "    ${GREEN}✓ $filename.png${NC}"
                else
                    FAILED=$((FAILED + 1))
                    echo -e "    ${RED}✗ Failed${NC}"
                fi
                ;;
        esac

        echo ""
    fi
done

# 결과 요약
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Conversion Complete${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Total:   $TOTAL diagrams"
echo -e "Success: ${GREEN}$SUCCESS${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo ""

if [ $SUCCESS -gt 0 ]; then
    echo "Images saved to: $OUTPUT_DIR"
    echo ""
    ls -lh "$OUTPUT_DIR"/*.png 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
fi
